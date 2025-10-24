import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/terminal.dart';

class TerminalService {
  final CollectionReference terminals = FirebaseFirestore.instance.collection('terminals');

  Future<void> addTerminal(Terminal t) => terminals.add(t.toMap());
  Future<void> updateTerminal(String id, Terminal t) => terminals.doc(id).update(t.toMap());
  Future<void> deleteTerminal(String id) => terminals.doc(id).delete();

  Stream<List<Terminal>> getTerminals() {
    return terminals.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Terminal.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }
}
