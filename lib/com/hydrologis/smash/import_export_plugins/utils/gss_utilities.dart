/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

import 'dart:convert';

import 'package:smashlibs/smashlibs.dart';

/// @author hydrologis
class GssUtilities {
  static final int DEFAULT_BYTE_ARRAY_READ = 8192;

  static final String MASTER_GSS_PASSWORD = "gss_Master_Survey_Forever_2018";

  static final int MPR_TIMEOUT = 5 * 60 * 1000; // 5 minutes timeout

  static final String LAST_DB_PATH = "GSS_LAST_DB_PATH";
  static final String SERVER_URL = "GSS_SERVER_URL";

  static final String SYNCH_PATH = "/upload";
  static final String DATA_DOWNLOAD_PATH = "/datadownload";
  static final String TAGS_DOWNLOAD_PATH = "/tagsdownload";

  static final String DATA_DOWNLOAD_MAPS = "maps";
  static final String DATA_DOWNLOAD_PROJECTS = "projects";
  static final String DATA_DOWNLOAD_NAME = "name";

  static final String TAGS_DOWNLOAD_TAGS = "tags";
  static final String TAGS_DOWNLOAD_TAG = "tag";
  static final String TAGS_DOWNLOAD_NAME = "name";

//     static String NATIVE_BROWSER_USE = "GSS_NATIVE_BROWSER_USE";
  static final double ICON_SIZE = 4;
  static final double BIG_ICON_SIZE = 8;
  static final String YES = "Yes";
  static final String NO = "No";

  static Future<String> getAuthHeader(String password) async {
    String deviceId =
        GpPreferences().getStringSync(SmashPreferencesKeys.DEVICE_ID_OVERRIDE);
    deviceId ??= GpPreferences().getStringSync(
        SmashPreferencesKeys.DEVICE_ID, await Device().getDeviceId());
    if (deviceId == null) {
      return null;
    }
    String authCode =
        deviceId + ":" + (password ?? GssUtilities.MASTER_GSS_PASSWORD);
    String authHeader =
        "Basic " + const Base64Encoder().convert(authCode.codeUnits);
    return authHeader;
  }

  static final String NOTE_OBJID = "note";
  static final String IMAGE_OBJID = "image";
  static final String LOG_OBJID = "gpslog";
  static final String OBJID_TYPE_KEY = "type";
}
