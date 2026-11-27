export async function signInUser(email: string, password: string) {
  const token = await login(email, password);
  await AsyncStorage.setItem('access_token', token);
}
