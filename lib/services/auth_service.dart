import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    final res = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return res.user;
  }

  Future<User?> register(String email, String password) async {
    final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return res.user;
  }

  Future<void> signOut() async => await _auth.signOut();

  bool isAdmin(User user) => user.email == "admin@example.com";
}
