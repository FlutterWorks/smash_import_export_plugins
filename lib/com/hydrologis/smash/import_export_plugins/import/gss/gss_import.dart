part of smash_import_export_plugins;

/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

class GssImportPlugin extends AImportPlugin {
  late ProjectDb projectDb;
  late BuildContext context;

  @override
  void setContext(BuildContext context) {
    this.context = context;
  }

  @override
  Icon getIcon() {
    return Icon(
      MdiIcons.cloudLock,
      color: SmashColors.mainDecorations,
    );
  }

  @override
  String getTitle() {
    return "GSS";
  }

  @override
  String getDescription() {
    return IEL.of(context).importWidget_importFromGeopaparazzi;
  }

  @override
  void setProjectDatabase(ProjectDb projectDb) {
    this.projectDb = projectDb;
  }

  @override
  Widget getImportPage() {
    return const GssImportWidget();
  }

  @override
  Widget getSettingsPage() {
    return GssSettings();
  }
}

class GssImportWidget extends StatefulWidget {
  const GssImportWidget({Key? key}) : super(key: key);

  @override
  _GssImportWidgetState createState() => _GssImportWidgetState();
}

class _GssImportWidgetState extends State<GssImportWidget>
    with AfterLayoutMixin {
  /*
   * 0 = waiting
   * 1 = has data
   *
   * 10 = no token available
   * 11 = no server url available
   * 12 = download list error
   * 13 = permission denied error
   * 14 = insecure http not allowed
   * 15 = no project selected
   * 100 = generic error
   */
  int _status = 0;
  late String _genericErrorMessage;
  late Map<String, String> tokenHeader;

  Project? _selectedProject;
  late String _mapsFolderPath;
  late String _projectsFolderPath;
  late String _formsFolderPath;
  String? _serverUrl;
  final List<dynamic> _baseMapsList = [];
  final List<dynamic> _projectsList = [];
  final List<dynamic> _tagsList = [];

  @override
  void afterFirstLayout(BuildContext context) {
    init();
  }

  Future<void> init() async {
    var selectedProjectJson = GpPreferences()
        .getStringSync(SmashPreferencesKeys.KEY_GSS_DJANGO_SERVER_PROJECT);
    if (selectedProjectJson == null) {
      setState(() {
        _status = 15;
      });
      return;
    }
    _selectedProject = Project.fromJson(selectedProjectJson);

    var token = ServerApi.getGssToken();
    if (token == null) {
      setState(() {
        _status = 10;
      });
      return;
    }
    tokenHeader = ServerApi.getTokenHeader();

    Directory mapsFolder = await Workspace.getMapsFolder();
    _mapsFolderPath = mapsFolder.path;
    Directory projectsFolder = await Workspace.getProjectsFolder();
    _projectsFolderPath = projectsFolder.path;
    Directory formsFolder = await Workspace.getFormsFolder();
    _formsFolderPath = formsFolder.path;

    _serverUrl = GpPreferences()
        .getStringSync(SmashPreferencesKeys.KEY_GSS_DJANGO_SERVER_URL);
    if (_serverUrl == null) {
      setState(() {
        _status = 11;
      });
      return;
    }

    try {
      List<dynamic>? projectData = await ServerApi.getProjectData();
      if (projectData == null) {
        projectData = [];
      }
      _baseMapsList.clear();
      _projectsList.clear();
      for (var bm in projectData) {
        var name = bm['label'];
        if (FileManager.isVectordataFile(name) ||
            FileManager.isTiledataFile(name)) {
          _baseMapsList.add(bm);
        } else if (FileManager.isProjectFile(name)) {
          _projectsList.add(bm);
        } else if (name.endsWith("_tags.json")) {
          _tagsList.add(bm);
        }
      }

      setState(() {
        _status = 1;
      });
    } on Exception catch (e, s) {
      if (e is DioError) {
        if (e.response != null) {
          var code = e.response?.statusCode;
          var msg = e.response?.statusMessage ?? "no message";
          if (code == 403) {
            setState(() {
              _status = 13;
            });
          } else {
            setState(() {
              _genericErrorMessage = msg;
              _status = 100;
            });
            SMLogger().e(msg, e, s);
          }
        } else if (e.message.isNotEmpty) {
          setState(() {
            _genericErrorMessage = e.message;
            _status = 100;
          });
          SMLogger().e(e.message, e, s);
        }
      } else {
        setState(() {
          _status = 12;
        });
        SMLogger()
            .e("An error occurred while downloading GSS data list.", e, s);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // make sure new tags are read
        await TagsManager().readFileTags();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(IEL.of(context).gssImport_gssImport), //"GSS Import"
        ),
        body: _status == 0
            ? Center(
                child: SmashCircularProgress(
                    label: IEL
                        .of(context)
                        .gssImport_downloadingDataList), //"Downloading data list..."
              )
            : _status == 12
                ? Center(
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: SmashUI.errorWidget(IEL
                          .of(context)
                          .gssImport_unableDownloadDataList), //"Unable to download data list due to an error. Check your settings and the log."
                    ),
                  )
                : _status == 11
                    ? Center(
                        child: Padding(
                          padding: SmashUI.defaultPadding(),
                          child: SmashUI.titleText(IEL
                              .of(context)
                              .gssImport_noGssUrlSet), //"No GSS server url has been set. Check your settings."
                        ),
                      )
                    : _status == 10
                        ? Center(
                            child: Padding(
                              padding: SmashUI.defaultPadding(),
                              child: SmashUI.titleText(
                                  "No access token available. Check your settings."),
                            ),
                          )
                        : _status == 13
                            ? Center(
                                child: Padding(
                                  padding: SmashUI.defaultPadding(),
                                  child: SmashUI.errorWidget(IEL
                                      .of(context)
                                      .gssImport_noPermToAccessServer), //"No permission to access the server. Check your credentials."
                                ),
                              )
                            : _status == 14
                                ? Center(
                                    child: Padding(
                                      padding: SmashUI.defaultPadding(),
                                      child: SmashUI.errorWidget(
                                          "Insecure http is not allowed by the platform. check your server URL."),
                                    ),
                                  )
                                : _status == 100
                                    ? Center(
                                        child: Padding(
                                          padding: SmashUI.defaultPadding(),
                                          child: SmashUI.errorWidget(
                                              _genericErrorMessage),
                                        ),
                                      )
                                    : getOkView(context),
      ),
    );
  }

  Widget getOkView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            child: Card(
              margin: SmashUI.defaultMargin(),
              elevation: SmashUI.DEFAULT_ELEVATION,
              color: SmashColors.mainBackground,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.titleText(_selectedProject!.name,
                        bold: true, color: SmashColors.mainSelection),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            child: Card(
              margin: SmashUI.defaultMargin(),
              elevation: SmashUI.DEFAULT_ELEVATION,
              color: SmashColors.mainBackground,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.normalText(
                        IEL.of(context).gssImport_data, //"Data"
                        bold: true),
                  ),
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.smallText(
                        _baseMapsList.isNotEmpty
                            ? IEL
                                .of(context)
                                .gssImport_dataSetsDownloadedMapsFolder //"Datasets are downloaded into the maps folder."
                            : IEL
                                .of(context)
                                .gssImport_noDataAvailable, //"No data available."
                        color: Colors.grey),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _baseMapsList.length,
                    itemBuilder: (context, index) {
                      var map = _baseMapsList[index];
                      var name = map['label'];
                      String baseurl =
                          ServerApi.getBaseUrl(needFinalSlash: false);
                      String downloadUrl = baseurl + map['file'];

                      return FileDownloadListTileProgressWidget(
                        downloadUrl,
                        FileUtilities.joinPaths(_mapsFolderPath, name),
                        name,
                        tokenHeader: tokenHeader,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            child: Card(
              margin: SmashUI.defaultMargin(),
              elevation: SmashUI.DEFAULT_ELEVATION,
              color: SmashColors.mainBackground,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.normalText(
                        IEL.of(context).gssImport_projects, //"Projects"
                        bold: true),
                  ),
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.smallText(
                        _projectsList.isNotEmpty
                            ? IEL
                                .of(context)
                                .gssImport_projectsDownloadedProjectFolder //"Projects are downloaded into the projects folder."
                            : IEL
                                .of(context)
                                .gssImport_noProjectsAvailable, //"No projects available."
                        color: Colors.grey),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _projectsList.length,
                    itemBuilder: (context, index) {
                      var map = _projectsList[index];
                      var name = map['label'];
                      String baseurl =
                          ServerApi.getBaseUrl(needFinalSlash: false);
                      String downloadUrl = baseurl + map['file'];

                      return FileDownloadListTileProgressWidget(
                        downloadUrl,
                        FileUtilities.joinPaths(_projectsFolderPath, name),
                        name,
                        tokenHeader: tokenHeader,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            child: Card(
              margin: SmashUI.defaultMargin(),
              elevation: SmashUI.DEFAULT_ELEVATION,
              color: SmashColors.mainBackground,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.normalText(
                        IEL.of(context).gssImport_forms, //"Forms"
                        bold: true),
                  ),
                  Padding(
                    padding: SmashUI.defaultPadding(),
                    child: SmashUI.smallText(
                        _tagsList.isNotEmpty
                            ? IEL
                                .of(context)
                                .gssImport_tagsDownloadedFormsFolder //"Tags files are downloaded into the forms folder."
                            : IEL
                                .of(context)
                                .gssImport_noTagsAvailable, //"No tags available."
                        color: Colors.grey),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tagsList.length,
                    itemBuilder: (context, index) {
                      var map = _tagsList[index];
                      var name = map['label'];
                      String baseurl =
                          ServerApi.getBaseUrl(needFinalSlash: false);
                      String downloadUrl = baseurl + map['file'];

                      return FileDownloadListTileProgressWidget(
                        downloadUrl,
                        FileUtilities.joinPaths(_formsFolderPath, name),
                        name,
                        tokenHeader: tokenHeader,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
