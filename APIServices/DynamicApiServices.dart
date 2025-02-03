import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:ejlal3/Config/constants.dart';
import 'package:ejlal3/Helpers/SQliteDbHelper.dart';
import 'package:ejlal3/Models/CourseModel.dart';

import 'package:ejlal3/APIServices/DioClient.dart';

class ApiService {
  final DioClient _client = DioClient();
  DatabaseHelper _dbHelper= DatabaseHelper();
  //dyanamic post
  Future<dynamic> post(String url, {Object? data, Options? options}) async {
    options ??= Options(
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    );

    Response response = await _client.dio.post(
      url,
      data: data,
      options: options,
    );
    return response;
  }

  //dynamic get
  Future<dynamic> get(String url) async {
    return await _client.dio.get(url);
  }

  //dynamic put
  Future<dynamic> put(String url, {Object? data, Options? options}) async {
    Response response = await _client.dio.put(
      url,
      data: data,
      options: options,
    );
    return response;
  }

  Future<dynamic> delete(String url) async {
    Options _options = Options(
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return await _client.dio.delete(url);
  }

  ///////////////
  Future<void> sendCourseToServer(CourseModel course) async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult != ConnectivityResult.none) {
      try {
        FormData formData = FormData.fromMap(course.toJson());
        Response response = await post(baseURL+teachersAPI+addAPI, data: formData);

        if (response.statusCode == 201) {
          print("Course synced successfully: ${course.title}");
          await _dbHelper.markCourseAsSynced(course.id!);
        } else {
          print("Failed to sync course: ${response.data}");
        }
      } catch (e) {
        print("Error syncing course: $e");
      }
    } else {
      print("No internet. Course data saved locally.");
    }
  }

  Future<void> updateCourseOnServer(CourseModel course) async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      try {
        FormData formData = FormData.fromMap(course.toJson());
        Response response = await put("${baseURL+teachersAPI+updateAPI}${course.id}", data: formData);

        if (response.statusCode == 200) {
          print("Course updated successfully: ${course.title}");
          await _dbHelper.markCourseAsSynced(course.id);
        } else {
          print("Failed to update course: ${response.data}");
        }
      } catch (e) {
        print("Error updating course: $e");
      }
    } else {
      print("No internet. Update will be synced later.");
    }
  }

}