class AppStrings {
  const AppStrings._();

  static const String appName = 'MyPetTrip';

  // 한국관광공사 api key
  // https://www.data.go.kr/data/15135102/openapi.do?utm_source=chatgpt.com#/API%20%EB%AA%A9%EB%A1%9D
  static const String korTourApiKey = '';

  // open ai api
  // https://platform.openai.com/settings/proj_ZFnOu3EytdMOU6oMVXqs8aIs/api-keys
  static const String openAiApiKey = '';

  // geocoding api
  // https://console.cloud.google.com/google/maps-apis/credentials?project=mypettrip
  static const String googleGeocodingApiKey = '';

  static const String loginTitle = '로그인';
  static const String signUpTitle = '회원가입';
  static const String emailLabel = '이메일';
  static const String passwordLabel = '비밀번호';
  static const String confirmPasswordLabel = '비밀번호 확인';
  static const String loginButton = '로그인';
  static const String signUpButton = '회원가입';

  static const String homeTab = '홈';
  static const String nearbyTab = '내주변';
  static const String aiTab = 'AI';
  static const String favoriteTab = '찜';
  static const String myTab = '마이';

  static const String errorEmptyFields = '이메일과 비밀번호를 입력해 주세요.';
  static const String errorPasswordMismatch = '비밀번호가 일치하지 않아요.';
  static const String errorNetwork = '네트워크 상태를 확인해 주세요.';
  static const String errorUnknown = '알 수 없는 오류가 발생했어요.';
}
