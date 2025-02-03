
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ejlal3/APIServices/DynamicApiServices.dart';
import 'package:ejlal3/Helpers/SQliteDbHelper.dart';
import 'package:ejlal3/Models/CourseModel.dart';

class SyncService {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ApiService apiService = ApiService();

  Future<void> syncData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      List<CourseModel> localCourses = await dbHelper.getUnsyncedCourses();

      for (var course in localCourses) {
        await apiService.sendCourseToServer(course);
      }
    }
  }


  void monitorInternetConnection() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        syncData();
      }
    });
  }
}