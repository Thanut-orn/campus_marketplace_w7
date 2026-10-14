import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// คลาสสำหรับจัดการข้อผิดพลาดของการยืนยันตัวตน (Authentication)
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// บริการจัดการระบบยืนยันตัวตนด้วย Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// สตรีมตรวจสอบสถานะการเข้าสู่ระบบของผู้ใช้ (สำหรับ AuthGate)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ดึงข้อมูลผู้ใช้ปัจจุบันที่ล็อกอินอยู่
  User? get currentUser => _auth.currentUser;

  /// แปลงรหัส Error จาก Firebase เป็นข้อความภาษาไทยที่เข้าใจง่าย
  String _translateErrorCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้งานแล้วในระบบ';
      case 'weak-password':
        return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
      case 'invalid-credential':
        return 'ข้อมูลยืนยันตัวตนจาก Google ไม่ถูกต้องหรือหมดอายุ กรุณาลองเข้าสู่ระบบใหม่';
      case 'user-not-found':
        return 'ไม่พบบัญชีผู้ใช้นี้ในระบบ';
      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีผู้ใช้นี้ถูกระงับการใช้งาน';
      case 'too-many-requests':
        return 'มีการพยายามเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'operation-not-allowed':
        return 'ระบบยังไม่เปิดให้บริการลงทะเบียนด้วยอีเมล/รหัสผ่าน';
      case 'network-request-failed':
        return 'การเชื่อมต่อเครือข่ายล้มเหลว กรุณาตรวจสอบอินเทอร์เน็ต';
      default:
        return 'เกิดข้อผิดพลาดในการยืนยันตัวตน ($code)';
    }
  }

  /// สมัครสมาชิกด้วย Email และ Password
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translateErrorCode(e.code));
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการสมัครสมาชิก: $e');
    }
  }

  /// เข้าสู่ระบบด้วย Email และ Password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translateErrorCode(e.code));
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e');
    }
  }

  /// ออกจากระบบ
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translateErrorCode(e.code));
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการออกจากระบบ: $e');
    }
  }

  // --- ส่วนเพิ่มเติม: Google Sign-In (หัวข้อ 9.4) ---

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleReady = false;

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    // initialize() ต้องเรียกครั้งเดียวก่อนใช้งานเมธอดอื่นของ GoogleSignIn เสมอ
    await _googleSignIn.initialize();
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleReady();

      // authenticate() เปิดหน้าต่างให้ผู้ใช้เลือกบัญชี Google (แทนที่ signIn() ในเวอร์ชันเก่า)
      final googleUser = await _googleSignIn.authenticate();

      // idToken ได้แบบ synchronous จาก authentication ของบัญชีที่ล็อกอินแล้ว
      final idToken = googleUser.authentication.idToken;

      // accessToken ต้องขอเพิ่มผ่าน authorizationClient แยกต่างหาก
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );

      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translateErrorCode(e.code));
    }
  }
}
