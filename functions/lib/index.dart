import 'package:firebase_functions_interop/firebase_functions_interop.dart';
import 'package:bin/data_access/dpgs.dart';

void main () async {
	var httpsFunc = firebaseFunctions.https.onRequest((request, response) {
		await dpgsUpdateTournamentSchedules();
		response.send('Hello from Firebase Functions Dart Interop!');
	});

	exports.setProperty('updateTournaments', httpsFunc);
}

