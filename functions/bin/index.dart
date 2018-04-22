import 'package:firebase_functions_interop/firebase_functions_interop.dart';
import 'package:myproject_functions/data_access/dpgs.dart';

void main() {
  var httpsFunc = firebaseFunctions.https.onRequest((request, response) {
    dpgsUpdateTournamentSchedules().then((_) {
      response.send('Hello from Firebase Functions Dart Interop!');
    });
  });

  exports.setProperty('updateTournaments', httpsFunc);
}
