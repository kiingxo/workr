import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../models/worker.dart';

final workrBackendApiProvider = Provider<WorkrBackendApi>((ref) {
  return WorkrBackendApi(
    baseUrl: const String.fromEnvironment(
      'WORKR_BACKEND_URL',
      defaultValue: 'http://127.0.0.1:8080',
    ),
  );
});

class WorkrBackendApi {
  WorkrBackendApi({required this.baseUrl});

  final String baseUrl;
  final http.Client _client = http.Client();

  String? _token;
  bool _authInProgress = false;

  Future<void> ensureAuthenticated() async {
    if (_token != null || _authInProgress) return;

    _authInProgress = true;
    try {
      const email = 'demo@workr.app';
      const password = 'workr-demo-password';

      final loginResponse = await _client.post(
        _uri('/users/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (loginResponse.statusCode == 200) {
        final decoded = _decodeMap(loginResponse.body);
        _token = decoded['token'] as String?;
      } else {
        final registerResponse = await _client.post(
          _uri('/users/register'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email,
            'password': password,
            'display_name': 'Workr Demo',
          }),
        );

        if (registerResponse.statusCode != 201) {
          throw Exception(
            'Auth failed. login=${loginResponse.body}; register=${registerResponse.body}',
          );
        }
        final decoded = _decodeMap(registerResponse.body);
        _token = decoded['token'] as String?;
      }

      if (_token == null || _token!.isEmpty) {
        throw Exception('Auth token missing from backend response');
      }
    } finally {
      _authInProgress = false;
    }
  }

  Future<List<Worker>> listWorkers() async {
    final response = await _requestWithAuthRetry(
      () => _client.get(_uri('/workers'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => _workerFromBackend(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Worker> createWorker({
    required String name,
    required AgentType type,
    String? description,
    required double x,
    required double y,
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers'),
        headers: _authHeaders,
        body: jsonEncode({
          'name': name,
          'type': _agentTypeToBackend(type),
          'description': description ?? 'Automated task execution',
          'tools': _defaultToolsForType(type),
          'x': x,
          'y': y,
        }),
      ),
    );
    _checkResponse(response, expectedStatus: 201);
    return _workerFromBackend(_decodeMap(response.body));
  }

  Future<Worker> updateWorker({
    required String id,
    String? name,
    AgentType? type,
    String? description,
    WorkerStatus? status,
    double? x,
    double? y,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (type != null) body['type'] = _agentTypeToBackend(type);
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = _statusToBackend(status);
    if (x != null) body['x'] = x;
    if (y != null) body['y'] = y;

    final response = await _requestWithAuthRetry(
      () => _client.put(
        _uri('/workers/$id'),
        headers: _authHeaders,
        body: jsonEncode(body),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _workerFromBackend(_decodeMap(response.body));
  }

  Future<void> deleteWorker(String id) async {
    final response = await _requestWithAuthRetry(
      () => _client.delete(_uri('/workers/$id'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 204);
  }

  Future<void> runWorker(String id) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(_uri('/workers/$id/run'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 202);
  }

  Future<Worker> setWorkerAutoRun({
    required String id,
    required bool enabled,
    int intervalMinutes = 60,
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers/$id/auto-run'),
        headers: _authHeaders,
        body: jsonEncode({
          'enabled': enabled,
          'interval_minutes': intervalMinutes,
        }),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _workerFromBackend(_decodeMap(response.body));
  }

  Future<WorkerExecutionResult> getWorkerExecutionResult(String id) async {
    final response = await _requestWithAuthRetry(
      () => _client.get(_uri('/workers/$id'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = _decodeMap(response.body);

    final workerStatus = _statusFromBackend(
      decoded['status']?.toString() ?? '',
    );
    final message = _extractBestWorkerLogMessage(decoded['logs']);

    return WorkerExecutionResult(status: workerStatus, message: message);
  }

  Future<EmailInboxSnapshot> getUnreadEmails({
    required String workerId,
    int limit = 20,
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.get(
        _uri('/workers/$workerId/email/unread?limit=$limit'),
        headers: _authHeaders,
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = _decodeMap(response.body);
    final unreadCount = (decoded['unread_count'] as num?)?.toInt() ?? 0;
    final messagesRaw = decoded['messages'];
    final messages = (messagesRaw is List ? messagesRaw : const [])
        .whereType<Map>()
        .map(
          (item) => EmailInboxMessage(
            id: item['id']?.toString() ?? '',
            from: item['from']?.toString() ?? '',
            subject: item['subject']?.toString() ?? '(no subject)',
            snippet: item['snippet']?.toString() ?? '',
            received: item['received']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
    return EmailInboxSnapshot(unreadCount: unreadCount, messages: messages);
  }

  Future<EmailReplyDraft> generateReplyDraft({
    required String workerId,
    required String messageId,
    String tone = 'professional',
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers/$workerId/email/reply-draft'),
        headers: _authHeaders,
        body: jsonEncode({'message_id': messageId, 'tone': tone}),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = _decodeMap(response.body);
    return EmailReplyDraft(
      messageId: decoded['message_id']?.toString() ?? messageId,
      to: decoded['to']?.toString() ?? '',
      subject: decoded['subject']?.toString() ?? 'Re: your email',
      body: decoded['body']?.toString() ?? '',
      threadId: decoded['thread_id']?.toString() ?? '',
    );
  }

  Future<void> sendReply({
    required String workerId,
    required String messageId,
    required String to,
    required String subject,
    required String body,
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers/$workerId/email/reply-send'),
        headers: _authHeaders,
        body: jsonEncode({
          'message_id': messageId,
          'to': to,
          'subject': subject,
          'body': body,
        }),
      ),
    );
    _checkResponse(response, expectedStatus: 202);
  }

  Future<ResearchRunResult> runResearch({
    required String workerId,
    required String query,
    List<String> sources = const [],
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers/$workerId/research/run'),
        headers: _authHeaders,
        body: jsonEncode({'query': query, 'sources': sources}),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _researchRunFromMap(_decodeMap(response.body));
  }

  Future<TransitWatchConfig> getTransitConfig(String workerId) async {
    final response = await _requestWithAuthRetry(
      () => _client.get(
        _uri('/workers/$workerId/transit/config'),
        headers: _authHeaders,
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _transitConfigFromMap(_decodeMap(response.body));
  }

  Future<TransitWatchConfig> saveTransitConfig({
    required String workerId,
    required String destination,
    String origin = '',
    int alertMinutesBefore = 8,
    int pollIntervalMinutes = 2,
    String telegramChatId = '',
    String notifyChannel = 'telegram',
    String whatsAppTo = '',
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.put(
        _uri('/workers/$workerId/transit/config'),
        headers: _authHeaders,
        body: jsonEncode({
          'origin': origin,
          'destination': destination,
          'alert_minutes_before': alertMinutesBefore,
          'poll_interval_minutes': pollIntervalMinutes,
          'telegram_chat_id': telegramChatId,
          'notify_channel': notifyChannel,
          'whatsapp_to': whatsAppTo,
        }),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _transitConfigFromMap(_decodeMap(response.body));
  }

  Future<ResearchRunResult?> getLatestResearchRun(String workerId) async {
    final response = await _requestWithAuthRetry(
      () => _client.get(
        _uri('/workers/$workerId/research/latest'),
        headers: _authHeaders,
      ),
    );
    if (response.statusCode == 404) return null;
    _checkResponse(response, expectedStatus: 200);
    return _researchRunFromMap(_decodeMap(response.body));
  }

  Future<List<WorkerTask>> listWorkerTasks(String workerId) async {
    final response = await _requestWithAuthRetry(
      () =>
          _client.get(_uri('/workers/$workerId/tasks'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => _workerTaskFromMap(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<WorkerTask>> listTasks({String? status}) async {
    final query = (status == null || status.trim().isEmpty)
        ? ''
        : '?status=${Uri.encodeQueryComponent(status.trim())}';
    final response = await _requestWithAuthRetry(
      () => _client.get(_uri('/tasks$query'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => _workerTaskFromMap(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<WorkerTask> assignTask({
    required String taskId,
    required String workerId,
  }) async {
    final workerIdInt = int.tryParse(workerId);
    if (workerIdInt == null) {
      throw Exception('Invalid worker id for assignment: $workerId');
    }
    final response = await _requestWithAuthRetry(
      () => _client.put(
        _uri('/tasks/$taskId/assign'),
        headers: _authHeaders,
        body: jsonEncode({'assigned_worker_id': workerIdInt}),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _workerTaskFromMap(_decodeMap(response.body));
  }

  Future<WorkerTask> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.put(
        _uri('/tasks/$taskId/status'),
        headers: _authHeaders,
        body: jsonEncode({'status': status}),
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    return _workerTaskFromMap(_decodeMap(response.body));
  }

  Future<void> runTask(String taskId) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(_uri('/tasks/$taskId/run'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 202);
  }

  Future<List<WorkerTask>> createTasksFromLatestResearch({
    required String workerId,
    List<String> selectedCardIds = const [],
  }) async {
    final response = await _requestWithAuthRetry(
      () => _client.post(
        _uri('/workers/$workerId/research/tasks/from-latest'),
        headers: _authHeaders,
        body: jsonEncode({'selected_card_ids': selectedCardIds}),
      ),
    );
    _checkResponse(response, expectedStatus: 201);
    final decoded = _decodeMap(response.body);
    final tasksRaw = decoded['tasks'];
    if (tasksRaw is! List) return const [];
    return tasksRaw
        .whereType<Map>()
        .map((e) => _workerTaskFromMap(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<String> googleOAuthStartUrl() async {
    final response = await _requestWithAuthRetry(
      () => _client.get(
        _uri('/integrations/oauth/google/start'),
        headers: _authHeaders,
      ),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = _decodeMap(response.body);
    final authUrl = decoded['auth_url']?.toString();
    if (authUrl == null || authUrl.isEmpty) {
      throw Exception('Backend response missing auth_url');
    }
    return authUrl;
  }

  Future<bool> hasGoogleIntegration() async {
    final response = await _requestWithAuthRetry(
      () => _client.get(_uri('/integrations'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.any((item) {
      final integration = item as Map<String, dynamic>;
      final provider =
          (integration['provider'] ?? integration['Provider'])?.toString() ??
          '';
      return provider.toLowerCase() == 'google';
    });
  }

  Future<void> disconnectGoogle() async {
    final response = await _requestWithAuthRetry(
      () => _client.get(_uri('/integrations'), headers: _authHeaders),
    );
    _checkResponse(response, expectedStatus: 200);
    final decoded = jsonDecode(response.body) as List<dynamic>;

    final googleIntegrationIds = decoded
        .map((item) => item as Map<String, dynamic>)
        .where((integration) {
          final provider =
              (integration['provider'] ?? integration['Provider'])
                  ?.toString() ??
              '';
          return provider.toLowerCase() == 'google';
        })
        .map(
          (integration) => (integration['id'] ?? integration['ID'])?.toString(),
        )
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    for (final id in googleIntegrationIds) {
      final deleteResponse = await _requestWithAuthRetry(
        () => _client.delete(_uri('/integrations/$id'), headers: _authHeaders),
      );
      _checkResponse(deleteResponse, expectedStatus: 204);
    }
  }

  Stream<WorkerStatusEvent> workerEvents() async* {
    final response = await _sendWithAuthRetry('/workers/stream');
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('SSE connection failed: ${response.statusCode} $body');
    }

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final rawPayload = line.substring(6);
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;

      final workerId = decoded['worker_id']?.toString();
      if (workerId == null) continue;

      yield WorkerStatusEvent(
        workerId: workerId,
        status: _statusFromBackend(decoded['status']?.toString() ?? ''),
        message: decoded['message']?.toString(),
      );
    }
  }

  void dispose() {
    _client.close();
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
  };

  Map<String, String> get _authHeaders => {
    ..._jsonHeaders,
    'Authorization': 'Bearer $_token',
  };

  Future<http.Response> _requestWithAuthRetry(
    Future<http.Response> Function() request,
  ) async {
    await ensureAuthenticated();
    var response = await request();
    if (response.statusCode != 401) return response;

    _token = null;
    await ensureAuthenticated();
    response = await request();
    return response;
  }

  Future<http.StreamedResponse> _sendWithAuthRetry(String path) async {
    await ensureAuthenticated();
    var request = http.Request('GET', _uri(path));
    request.headers.addAll(_authHeaders);
    var response = await _client.send(request);
    if (response.statusCode != 401) return response;

    _token = null;
    await ensureAuthenticated();
    request = http.Request('GET', _uri(path));
    request.headers.addAll(_authHeaders);
    response = await _client.send(request);
    return response;
  }

  void _checkResponse(http.Response response, {required int expectedStatus}) {
    if (response.statusCode == expectedStatus) return;
    throw Exception(
      'Backend error ${response.statusCode} (expected $expectedStatus): ${response.body}',
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

class WorkerStatusEvent {
  const WorkerStatusEvent({
    required this.workerId,
    required this.status,
    required this.message,
  });

  final String workerId;
  final WorkerStatus status;
  final String? message;
}

class WorkerExecutionResult {
  const WorkerExecutionResult({required this.status, required this.message});

  final WorkerStatus status;
  final String? message;
}

class EmailInboxSnapshot {
  const EmailInboxSnapshot({required this.unreadCount, required this.messages});

  final int unreadCount;
  final List<EmailInboxMessage> messages;
}

class EmailInboxMessage {
  const EmailInboxMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.snippet,
    required this.received,
  });

  final String id;
  final String from;
  final String subject;
  final String snippet;
  final String received;
}

class EmailReplyDraft {
  const EmailReplyDraft({
    required this.messageId,
    required this.to,
    required this.subject,
    required this.body,
    required this.threadId,
  });

  final String messageId;
  final String to;
  final String subject;
  final String body;
  final String threadId;
}

class ResearchRunResult {
  const ResearchRunResult({
    required this.id,
    required this.query,
    required this.summary,
    required this.sources,
    required this.actionCards,
    required this.createdAt,
  });

  final String id;
  final String query;
  final String summary;
  final List<String> sources;
  final List<ResearchActionCard> actionCards;
  final DateTime? createdAt;
}

class ResearchActionCard {
  const ResearchActionCard({
    required this.id,
    required this.title,
    required this.details,
    required this.owner,
    required this.dueHint,
    required this.priority,
    required this.confidence,
  });

  final String id;
  final String title;
  final String details;
  final String owner;
  final String dueHint;
  final String priority;
  final int confidence;
}

class WorkerTask {
  const WorkerTask({
    required this.id,
    required this.workerId,
    required this.assignedWorkerId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.lastResultSummary,
    required this.lastRunAt,
    required this.completedAt,
  });

  final String id;
  final String workerId;
  final String? assignedWorkerId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String lastResultSummary;
  final DateTime? lastRunAt;
  final DateTime? completedAt;
}

class TransitWatchConfig {
  const TransitWatchConfig({
    required this.workerId,
    required this.origin,
    required this.destination,
    required this.alertMinutesBefore,
    required this.telegramChatId,
    required this.notifyChannel,
    required this.whatsAppTo,
    required this.pollIntervalMinutes,
    required this.autoRunEnabled,
  });

  final String workerId;
  final String origin;
  final String destination;
  final int alertMinutesBefore;
  final String telegramChatId;
  final String notifyChannel;
  final String whatsAppTo;
  final int pollIntervalMinutes;
  final bool autoRunEnabled;
}

Worker _workerFromBackend(Map<String, dynamic> json) {
  final backendId = json['id'] ?? json['ID'];
  final workerId = backendId?.toString();
  if (workerId == null || workerId.isEmpty || workerId == 'null') {
    throw Exception('Backend worker payload missing ID: $json');
  }

  return Worker(
    id: workerId,
    name: json['name']?.toString() ?? 'Unnamed Worker',
    description: json['description']?.toString().trim().isEmpty ?? true
        ? 'Automated task execution'
        : json['description'].toString(),
    type: _agentTypeFromBackend(json['type']?.toString() ?? ''),
    status: _statusFromBackend(json['status']?.toString() ?? ''),
    autoRunEnabled: (json['auto_run_enabled'] as bool?) ?? false,
    x: _toDouble(json['x']) ?? _toDouble(json['pos_x']) ?? 40,
    y: _toDouble(json['y']) ?? _toDouble(json['pos_y']) ?? 40,
  );
}

List<String> _defaultToolsForType(AgentType type) {
  return switch (type) {
    AgentType.email => ['gmail', 'calendar'],
    AgentType.socialContent => ['linkedin', 'scheduler'],
    AgentType.financeOps => ['banking', 'receipts', 'budgeting'],
    AgentType.research => ['web_search', 'documents', 'summarizer'],
    AgentType.taskWorkflow => ['notion', 'trello', 'slack'],
    AgentType.transitMaps => ['google_maps_transit', 'telegram'],
  };
}

AgentType _agentTypeFromBackend(String value) {
  return switch (value) {
    'email_action' => AgentType.email,
    'social_content' => AgentType.socialContent,
    'finance_ops' => AgentType.financeOps,
    'research_multi_source' => AgentType.research,
    'task_workflow' => AgentType.taskWorkflow,
    'maps_transit_alert' => AgentType.transitMaps,
    _ => AgentType.taskWorkflow,
  };
}

String _agentTypeToBackend(AgentType value) {
  return switch (value) {
    AgentType.email => 'email_action',
    AgentType.socialContent => 'social_content',
    AgentType.financeOps => 'finance_ops',
    AgentType.research => 'research_multi_source',
    AgentType.taskWorkflow => 'task_workflow',
    AgentType.transitMaps => 'maps_transit_alert',
  };
}

WorkerStatus _statusFromBackend(String value) {
  return switch (value) {
    'running' => WorkerStatus.running,
    'error' => WorkerStatus.error,
    'completed' => WorkerStatus.idle,
    'idle' => WorkerStatus.idle,
    _ => WorkerStatus.idle,
  };
}

String _statusToBackend(WorkerStatus value) {
  return switch (value) {
    WorkerStatus.running => 'running',
    WorkerStatus.idle => 'idle',
    WorkerStatus.error => 'error',
  };
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

ResearchRunResult _researchRunFromMap(Map<String, dynamic> json) {
  final sourcesRaw = json['sources'];
  final cardsRaw = json['action_cards'];
  return ResearchRunResult(
    id: (json['id'] ?? json['ID'])?.toString() ?? '',
    query: json['query']?.toString() ?? '',
    summary: json['summary']?.toString() ?? '',
    sources: (sourcesRaw is List ? sourcesRaw : const [])
        .map((e) => e.toString())
        .toList(growable: false),
    actionCards: (cardsRaw is List ? cardsRaw : const [])
        .whereType<Map>()
        .map(
          (card) => ResearchActionCard(
            id: card['id']?.toString() ?? '',
            title: card['title']?.toString() ?? 'Untitled',
            details: card['details']?.toString() ?? '',
            owner: card['owner']?.toString() ?? '',
            dueHint: card['due_hint']?.toString() ?? '',
            priority: card['priority']?.toString() ?? 'medium',
            confidence: (card['confidence'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );
}

WorkerTask _workerTaskFromMap(Map<String, dynamic> json) {
  return WorkerTask(
    id: (json['id'] ?? json['ID'])?.toString() ?? '',
    workerId: (json['worker_id'] ?? json['WorkerID'])?.toString() ?? '',
    assignedWorkerId: (json['assigned_worker_id'] ?? json['AssignedWorkerID'])
        ?.toString(),
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    status: json['status']?.toString() ?? 'todo',
    priority: json['priority']?.toString() ?? 'medium',
    lastResultSummary: json['last_result_summary']?.toString() ?? '',
    lastRunAt: DateTime.tryParse(json['last_run_at']?.toString() ?? ''),
    completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
  );
}

TransitWatchConfig _transitConfigFromMap(Map<String, dynamic> json) {
  return TransitWatchConfig(
    workerId: (json['worker_id'] ?? json['workerId'])?.toString() ?? '',
    origin: json['origin']?.toString() ?? '',
    destination: json['destination']?.toString() ?? '',
    alertMinutesBefore: (json['alert_minutes_before'] as num?)?.toInt() ?? 8,
    telegramChatId: json['telegram_chat_id']?.toString() ?? '',
    notifyChannel: json['notify_channel']?.toString() ?? 'telegram',
    whatsAppTo: json['whatsapp_to']?.toString() ?? '',
    pollIntervalMinutes: (json['poll_interval_minutes'] as num?)?.toInt() ?? 2,
    autoRunEnabled: (json['auto_run_enabled'] as bool?) ?? false,
  );
}

String? _extractBestWorkerLogMessage(dynamic logsRaw) {
  if (logsRaw is! List || logsRaw.isEmpty) return null;

  final logs = logsRaw
      .whereType<Map>()
      .map((log) => log.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
  if (logs.isEmpty) return null;

  final sorted = [...logs]
    ..sort((a, b) => _logSortValue(a).compareTo(_logSortValue(b)));

  final nonRunning = sorted
      .where((log) {
        final status = (log['status'] ?? log['Status'])
            ?.toString()
            .toLowerCase();
        return status != 'running';
      })
      .toList(growable: false);

  final selected = nonRunning.isNotEmpty ? nonRunning.last : sorted.last;
  return (selected['message'] ?? selected['Message'])?.toString();
}

int _logSortValue(Map<String, dynamic> log) {
  final idRaw = (log['id'] ?? log['ID'])?.toString();
  final id = int.tryParse(idRaw ?? '');
  if (id != null) return id;

  final createdAt = (log['created_at'] ?? log['CreatedAt'])?.toString();
  final time = createdAt == null ? null : DateTime.tryParse(createdAt);
  return time?.microsecondsSinceEpoch ?? 0;
}
