import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ejlal3/APIServices/DynamicApiServices.dart';
import 'package:ejlal3/Config/constants.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:ejlal3/Helpers/SQliteDbHelper.dart';
import 'package:ejlal3/Models/CourseModel.dart';

class CourseController extends GetxController {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  var courseList = <CourseModel>[].obs;
  CourseModel? courseDetail;
  var isLoading = false.obs;
  final ApiService _apiService = ApiService();

  @override
  void onInit() {
    super.onInit();
    print("Initializing CourseController...");
    getCourseList(); // تحميل قائمة الدورات عند بدء التطبيق
    monitorInternetConnection(); // تشغيل مراقبة الإنترنت
  }

  // ✅ جلب قائمة الدورات من API أو SQLite بناءً على توفر الإنترنت
  // Future<void> getCourseList() async {
  //   try {
  //     isLoading(true);
  //
  //     // Check internet connectivity
  //     final isConnected = await NetworkHelper.isNetworkAvailable();
  //
  //     if (isConnected) {
  //       // Fetch data from the API
  //       final response = await _apiService.get(baseAPIURLV1 + teachersAPI);
  //       if (response.statusCode == 200) {
  //         final apiCourses = (response.data as List)
  //             .map((json) => CourseModel.fromJson(json))
  //             .toList();
  //
  //
  //
  //         // Update the UI with the latest data
  //         courseList.value = apiCourses;
  //       } else {
  //         Get.snackbar("Error", "Failed to fetch courses from API",
  //             snackPosition: SnackPosition.BOTTOM);
  //       }
  //     } else {
  //
  //       Get.snackbar("Info", "No internet connection. Showing local data.",
  //           snackPosition: SnackPosition.BOTTOM);
  //     }
  //   } catch (e) {
  //     Get.snackbar("Error", "Failed to fetch courses: $e",
  //         snackPosition: SnackPosition.BOTTOM);
  //     print(e);
  //   } finally {
  //     isLoading(false);
  //   }
  // }


  Future<void> getCourseList() async {
    try {
      isLoading(true);
      print("Fetching course list...");

      var connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (isConnected) {
        try {
          final response = await _apiService.get(baseAPIURLV1 + teachersAPI);
          if (response.statusCode == 200) {
            List<CourseModel> apiCourses = (response.data as List)
                .map((course) => CourseModel.fromJson(course))
                .toList();

            courseList.value = apiCourses;
            print("Courses from API: ${courseList.length}");

            // تحديث قاعدة البيانات المحلية
            await _databaseHelper.clearCourses();
            for (var course in apiCourses) {
              await _databaseHelper.insertCourse(course);
            }

            Get.snackbar("Success", "Data synced with the server!",
                snackPosition: SnackPosition.BOTTOM);
          } else {
            print("Failed to fetch courses from API");
            Get.snackbar("Error", "Failed to fetch from API. Showing local data.",
                snackPosition: SnackPosition.BOTTOM);
            courseList.value = await _databaseHelper.getCourses();
          }
        } catch (e) {
          print("API fetch error: $e");
          Get.snackbar("Error", "API fetch failed. Showing local data.",
              snackPosition: SnackPosition.BOTTOM);
          courseList.value = await _databaseHelper.getCourses();
        }
      } else {
        courseList.value = await _databaseHelper.getCourses();
        print("Courses from SQLite: ${courseList.length}");
        Get.snackbar("Info", "No internet connection. Showing local data.",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print("Error fetching courses: $e");
      Get.snackbar("Error", "Failed to fetch courses: $e",
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading(false);
      update(); // تحديث الواجهة تلقائيًا عند انتهاء جلب البيانات
    }
  }

  // ✅ مزامنة البيانات غير المتزامنة عند توفر الإنترنت
  Future<void> syncCourses() async {
    List<CourseModel> unsyncedCourses = await _databaseHelper.getUnsyncedCourses();

    for (var course in unsyncedCourses) {
      try {
        await _apiService.sendCourseToServer(course);
        await _databaseHelper.markCourseAsSynced(course.id!);
        print("Synced course: ${course.title}");
      } catch (e) {
        print("Failed to sync course: ${course.title}, error: $e");
      }
    }
  }

  // ✅ تشغيل المزامنة عند عودة الإنترنت تلقائيًا
  void monitorInternetConnection() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        syncCourses();
      }
    });
  }

  // ✅ إضافة دورة جديدة مع التحقق من الإنترنت
  void addCourse({
    required String title,
    required String overview,
    required String subject,
    File? photo,
  }) async {
    var data;
    dio.Options options = dio.Options(headers: {'Content-Type': 'application/json'});

    try {
      isLoading(true);

      final newCourse = CourseModel(
        id: DateTime.now().millisecondsSinceEpoch, // ID مؤقت
        title: title,
        subject: subject,
        overview: overview,
        photo: photo?.path ?? '',
        createdAt: DateTime.now().toIso8601String(),
      );

      var connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (isConnected) {
        // ✅ إرسال البيانات إلى API
        if (photo != null) {
          data = dio.FormData.fromMap({
            "subject": subject,
            "title": title,
            "overview": overview,
            "photo": dio.MultipartFile.fromFileSync(
              photo.path,
              filename: photo.path.split(Platform.pathSeparator).last,
            ),
          });
          options = dio.Options(headers: {'Content-Type': 'multipart/form-data'});
        } else {
          data = dio.FormData.fromMap({
            "subject": subject,
            "title": title,
            "overview": overview,
          });
        }

        final response = await _apiService.post(
            baseAPIURLV1 + teachersAPI + addAPI, data: data, options: options);

        if (response.statusCode == 201) {
          Get.snackbar('Success', 'Course added successfully');
        } else {
          Get.snackbar('Error', response.data['error']);
        }
      } else {
        // ✅ إذا لم يكن هناك إنترنت، احفظ البيانات محليًا
        await _databaseHelper.insertCourse(newCourse);
        Get.snackbar('Info', 'No internet. Course saved locally.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to add course: $e');
    } finally {
      isLoading(true);
      getCourseList(); // تحديث قائمة الدورات
    }
  }
  // ✅ جلب تفاصيل دورة معينة بناءً على توفر الإنترنت
  Future<void> getCourseDetails(int courseId) async {
    try {
      isLoading(true);
      print("Fetching course details for ID: $courseId");

      var connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (isConnected) {
        // ✅ إذا كان الإنترنت متاحًا → جلب التفاصيل من API
        try {
          final response = await _apiService.get("${baseAPIURLV1 + teachersAPI}$courseId/");
          print("SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS${response.statusCode}");
          if (response.statusCode == 200) {
            courseDetail = CourseModel.fromJson(response.data)!;
          } else {
            print("Failed to fetch course from API, trying local data...");
            courseDetail = (await _databaseHelper.getCourseById(courseId))!;
          }
        } catch (e) {
          print("API fetch error: $e. Trying local data...");
          courseDetail = (await _databaseHelper.getCourseById(courseId))!;
        }
      } else {
        // ✅ إذا لم يكن هناك إنترنت → جلب البيانات من SQLite فقط
        courseDetail = (await _databaseHelper.getCourseById(courseId)!)!;
        print("Fetched course from SQLite: ${courseDetail!.title}");
        Get.snackbar("Info", "No internet connection. Showing local data.",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print("Error fetching course details: $e");
      Get.snackbar("Error", "Failed to fetch course details: $e",
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading(true);
      update(); // تحديث الواجهة تلقائيًا بعد جلب التفاصيل
    }
  }
  // ✅ تحديث الدورة مع التحقق من الإنترنت
  void updateCourse(
      int courseId, {
        required String title,
        required String overview,
        required String subject,
        File? photo,
      }) async {
    try {
      isLoading(true);
      print("Updating course ID: $courseId");

      final updatedCourse = CourseModel(
        id: courseId,
        title: title,
        subject: subject,
        overview: overview,
        photo: photo?.path ?? '',
        createdAt: DateTime.now().toIso8601String(),
      );

      var connectivityResult = await Connectivity().checkConnectivity();
      bool isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (isConnected) {
        // ✅ إذا كان الإنترنت متاحًا، قم بتحديث البيانات في `API`
        try {
          var data;
          dio.Options options = dio.Options(headers: {'Content-Type': 'application/json'});

          if (photo != null) {
            data = dio.FormData.fromMap({
              "subject": subject,
              "title": title,
              "overview": overview,
              "photo": dio.MultipartFile.fromFileSync(
                photo.path,
                filename: photo.path.split(Platform.pathSeparator).last,
              ),
            });
            options = dio.Options(headers: {'Content-Type': 'multipart/form-data'});
          } else {
            data = dio.FormData.fromMap({
              "subject": subject,
              "title": title,
              "overview": overview,
            });
          }

          final response = await _apiService.put(
              '${baseAPIURLV1 + teachersAPI}$courseId/$updateAPI/',
              data: data,
              options: options);

          if (response.statusCode == 200) {
            print("Course updated successfully in API: ${updatedCourse.title}");
            Get.snackbar('Success', 'Course updated successfully!',
                snackPosition: SnackPosition.BOTTOM);
          } else {
            print("Failed to update course in API, saving locally.");
            await _databaseHelper.updateCourse(updatedCourse);
            Get.snackbar('Info', 'Course updated locally. Sync when online.',
                snackPosition: SnackPosition.BOTTOM);
          }
        } catch (e) {
          print("API update failed: $e, saving locally.");
          await _databaseHelper.updateCourse(updatedCourse);
          Get.snackbar('Info', 'Course updated locally. Sync when online.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        // ✅ إذا لم يكن هناك إنترنت، احفظ التحديث محليًا فقط
        await _databaseHelper.updateCourse(updatedCourse);
        print("Course updated locally: ${updatedCourse.title}");
        Get.snackbar('Info', 'No internet. Course updated locally.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print("Error updating course: $e");
      Get.snackbar('Error', 'Failed to update course: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading(false);
      getCourseList(); // تحديث القائمة بعد التعديل
    }
  }

}