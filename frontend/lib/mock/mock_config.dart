import '../services/llm_service.dart';
import '../services/llm_service_base.dart';
import 'mock_llm_service.dart';

/// Set to true to use scripted mock responses (no API key needed).
/// Set to false to use the real DeepSeek API.
/// This is the ONLY line you need to change to switch between modes.
const bool kUseMockLlm = true;

LlmServiceBase createLlmService() =>
    kUseMockLlm ? MockLlmService() : LlmService();
