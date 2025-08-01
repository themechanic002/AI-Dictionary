import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef ChatDeltaCallback = void Function(String delta);
typedef ChatCompleteCallback = void Function();
typedef ChatErrorCallback = void Function(Object error);

class OpenAIService {
  static bool _isInitialized = false;
  static Stream<OpenAIStreamChatCompletionModel>? _chatStream;
  static StreamSubscription<OpenAIStreamChatCompletionModel>? _subscription;

  static void dispose() {
    _subscription?.cancel();
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) {
      throw Exception('OPENAI_API_KEY가 설정되지 않았습니다.');
    }

    OpenAI.apiKey = apiKey;
    _isInitialized = true;
  }

  /*===============================================
  L1 단어 정의 생성
  ===============================================*/

  static void getL1WordDefinition(
    String word,
    String l1,
    String l2,
    ChatDeltaCallback onDelta,
    ChatCompleteCallback onComplete,
    ChatErrorCallback onError,
  ) async {
    try {
      await initialize();

      // 언어 설정 확인을 위한 로그
      print('=== OpenAI 서비스 언어 설정 ===');
      print('검색 단어: $word');
      print('출발 언어: $l1');
      print('도착 언어: $l2');
      print('==============================');

      final prompt =
          '''
'$word' 이 단어를 $l2로 알고 싶어요. 아래 예시와 같은 Markdown 형식으로 출력해 주세요.
단, 모든 설명은 $l1로 하세요.

[출력 형식 규칙]

1. Markdown은 반드시 아래의 형식으로 출력한다.
2. 검색 단어에 오타가 있으면 오타를 수정해서 '###단어'에 표기한다.
3. 만약 검색 결과가 없다면 아래 규칙을 모두 무시하고 "No result"라는 문자열만 출력할 것. 다른 문자열은 출력하지 않는다.
4. '품사', '뉘앙스' 항목은 반드시 $l1로 작성한다.
5. '### 대화 예시'는 총 최대 2세트. 하나의 세트는 $l2 대화와 번역된 $l1 대화로 구성. 순서는 $l2 대화부터.
6. '### 비슷한 표현'은 총 최대 4개. $l2 단어를 작성하고 그 뜻은 $l1로 작성한다.

아래는 중국어 단어 '照片'를 검색하고 영어로 설명한 예시입니다. 형식만 참고해서 출력하세요.

아래는 영어 단어 'change'를 검색하고 중국어로 설명한 예시입니다. 형식만 참고해서 출력하세요.

### 단어: `change`

### 사전적 뜻

#### 품사: **Verb**

| 단어 | 뉘앙스 |
| ------------ | --- |
| 改变 (gǎibiàn) | Often refers to changing abstract things like thoughts, behavior, situations, or attitudes. It implies a transformation or modification. |
| 变 (biàn)     | Emphasizes a state change, often natural or spontaneous, rather than intentional. |
| 换 (huàn)     | Physical or concrete swapping or replacing something with another. Often used for clothes, money, items. |

#### 품사: **Noun**

| 단어 | 뉘앙스 |
| ------------- | ---- |
| 变化 (biànhuà)  | Focuses on the result or process of change, often gradual or natural. Unlike 改变 (which often implies intent), 变化 emphasizes transformation over time — of state, situation, mood, etc. |
| 零钱 (língqián) | Refers specifically to coins or small denominations of money, often used when paying cash. In English, this is the monetary meaning of change.                                         |

### 대화 예시

#### 예시1

**중국어**

* A: "我想换工作。"
* B: "为什么？发生什么事了？"

**영어**

* A: "I want to change my job."
* B: "Why? What happened?"

#### 예시 2
//생략

### 비슷한 표현

| 단어 | 뜻 |
| -- | --- |
| 调整 | adjust; used in situations involving fine-tuning or minor changes |
| 转变 | shift or transformation, especially in perspective or roles |

''';

      // 생성된 프롬프트 확인
      print('=== 생성된 프롬프트 ===');
      print(prompt);
      print('======================');

      final systemMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            '당신은 $l1 사용자의 $l2 학습을 돕는 언어 전문가입니다.',
          ),
        ],
        role: OpenAIChatMessageRole.system,
      );

      // the user message that will be sent to the request.
      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
        ],
        role: OpenAIChatMessageRole.user,
      );

      // all messages to be sent.
      final requestMessages = [systemMessage, userMessage];

      // the actual request.
      final stream = OpenAI.instance.chat.createStream(
        model: "gpt-4.1-mini",
        messages: requestMessages,
        temperature: 0.1,
        maxTokens: 700,
      );

      _subscription = stream.listen(
        (event) {
          final deltaText = event.choices.first.delta.content![0]?.text ?? '';
          if (deltaText != '') onDelta(deltaText.toString());
        },
        onDone: onComplete,
        onError: onError,
      );
    } catch (e) {
      print('OpenAI API 호출 오류: $e');
    }
  }

  /*===============================================
  L2 단어 정의 생성
  ===============================================*/

  static void getL2WordDefinition(
    String word,
    String l1,
    String l2,
    ChatDeltaCallback onDelta,
    ChatCompleteCallback onComplete,
    ChatErrorCallback onError,
  ) async {
    try {
      await initialize();

      // 언어 설정 확인을 위한 로그
      print('=== OpenAI 서비스 언어 설정 ===');
      print('검색 단어: $word');
      print('출발 언어: $l1');
      print('도착 언어: $l2');
      print('==============================');

      final prompt =
          '''
'$word' 이 단어를 $l2로 알고 싶어요. 아래 예시와 같은 Markdown 형식으로 출력해 주세요.
단, 모든 설명은 $l1로 하세요.

[출력 형식 규칙]

1. Markdown은 반드시 아래의 형식으로 출력한다.
2. 검색 단어에 오타가 있으면 오타를 수정해서 '###단어'에 표기한다.
3. 만약 검색 결과가 없다면 아래 규칙을 모두 무시하고 "No result"라는 문자열만 출력할 것. 다른 문자열은 출력하지 않는다.
4. '품사', '뜻', '뉘앙스' 항목은 반드시 $l1로 작성한다.
5. '### 대화 예시'는 총 최대 2세트. 하나의 세트는 $l2 대화와 번역된 $l1 대화로 구성. 순서는 $l2 대화부터.
6. '### 비슷한 표현'은 총 최대 4개. $l2 단어를 작성하고 그 뜻은 $l1로 작성한다.

아래는 중국어 단어 '照片'를 검색하고 영어로 설명한 예시입니다. 형식만 참고해서 출력하세요.

### 단어: `照片`

### 사전적 뜻

| 품사 | 뜻 |
| ---- | --- |
| Noun | photograph |
| Noun | photo |
| Noun | picture (taken with a camera) |

### 뉘앙스

‘**照片**’ refers to a photo or picture taken with a camera, typically printed or digital. It is a neutral, standard word used for personal, professional, or casual contexts.

### 대화 예시

#### 예시 1

**중국어**

* A: 你旅行的时候拍了照片吗？
* B: 拍了，我拍了很多好看的照片！

**영어**

* A: Did you take any photos on your trip?
* B: Yes, I took a lot of great photos!

#### 예시 2
//생략

### 비슷한 표현

| 단어 | 뜻 |
| -- | --- |
| 相片 | photo (synonym; interchangeable in most contexts) |
| 影像 | image; often used in technical or formal settings |

''';

      // 생성된 프롬프트 확인
      print('=== 생성된 프롬프트 ===');
      print(prompt);
      print('======================');

      final systemMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            '당신은 $l1 사용자의 $l2 학습을 돕는 언어 전문가입니다.',
          ),
        ],
        role: OpenAIChatMessageRole.system,
      );

      // the user message that will be sent to the request.
      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
        ],
        role: OpenAIChatMessageRole.user,
      );

      // all messages to be sent.
      final requestMessages = [systemMessage, userMessage];

      // the actual request.
      final stream = OpenAI.instance.chat.createStream(
        model: "gpt-4.1-mini",
        messages: requestMessages,
        temperature: 0.1,
        maxTokens: 700,
      );

      _subscription = stream.listen(
        (event) {
          final deltaText = event.choices.first.delta.content![0]?.text ?? '';
          if (deltaText != '') onDelta(deltaText.toString());
        },
        onDone: onComplete,
        onError: onError,
      );
    } catch (e) {
      print('OpenAI API 호출 오류: $e');
    }
  }

  static Future<String> translateText(
    String text,
    String fromLanguage,
    String toLanguage,
    String toneInstruction,
  ) async {
    try {
      await initialize();

      final prompt =
          '''
다음 텍스트를 $fromLanguage에서 $toLanguage로 번역해주세요.
$toneInstruction

번역할 텍스트: "$text"

번역 결과만 출력하고 다른 설명은 포함하지 마세요.
''';

      final systemMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            "You are a professional translator. Translate the given text accurately according to the specified tone and style. Respond only with the translated text without any additional comments or explanations.",
          ),
        ],
        role: OpenAIChatMessageRole.system,
      );

      final userMessage = OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
        ],
        role: OpenAIChatMessageRole.user,
      );

      final requestMessages = [systemMessage, userMessage];

      OpenAIChatCompletionModel chatCompletion = await OpenAI.instance.chat
          .create(
            model: "gpt-4.1-mini",
            messages: requestMessages,
            temperature: 0.2,
            maxTokens: 1000,
          );

      return chatCompletion.choices.first.message.haveContent
          ? chatCompletion.choices.first.message.content![0].text.toString()
          : '번역을 생성할 수 없습니다.';
    } catch (e) {
      print('OpenAI API 호출 오류: $e');
      return '죄송합니다. 현재 번역 서비스를 이용할 수 없습니다. 잠시 후 다시 시도해주세요.';
    }
  }
}
