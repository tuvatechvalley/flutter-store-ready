// decoy: the emulator address is limited to debug builds
const apiBaseUrl = kReleaseMode
    ? 'https://api.acme.app'
    : 'http://10.0.2.2:8000';
