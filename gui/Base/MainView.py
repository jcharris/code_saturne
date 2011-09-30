# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2011 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

"""
This module defines the main application classes for the Qt GUI.
This GUI provides a simple way to display independante pages, in order to put
informations in the XML document, which reflets the treated case.

This module defines the following classes:
- MainView

    @copyright: 1998-2009 EDF S.A., France
    @author: U{EDF R&D<mailto:saturne-support@edf.fr>}
    @license: GNU GPL v2, see COPYING for details.
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import os, sys, string, shutil, signal, logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules
#-------------------------------------------------------------------------------

from Base.MainForm import Ui_MainForm
from Base.IdView import IdView
from Base.BrowserView import BrowserView
from Base import XMLengine
from Base.XMLinitialize import *
from Base.XMLmodel import *
from Base.Toolbox import GuiParam, displaySelectedPage
from Base.Common import XML_DOC_VERSION, cs_batch_type

try:
    import Pages
except:
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from Pages.WelcomeView import WelcomeView
from Pages.IdentityAndPathesModel import IdentityAndPathesModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("MainView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Main Window
#-------------------------------------------------------------------------------

class MainView(QMainWindow, Ui_MainForm):

    NextId = 1
    Instances = set()

    def __init__(self,
                 package          = None,
                 cmd_case         = "",
                 cmd_batch_window = False,
                 cmd_batch_file   = 'runcase',
                 cmd_tree_window  = True,
                 cmd_read_only    = False,
                 cmd_salome       = None):
        """
        Initializes a Main Window for a new document:
          1. finish the Main Window layout
          2. connection betwenn signal and slot
          3. Ctrl+C signal handler
          4. create some instance variables
          5. restore system settings

        @type cmd_case:
        @param cmd_case:
        """
        QMainWindow.__init__(self)
        Ui_MainForm.__init__(self)

        self.setupUi(self)

        self.setAttribute(Qt.WA_DeleteOnClose)
        MainView.Instances.add(self)

        self.Id = IdView()
        self.dockWidgetIdentity.setWidget(self.Id)

        self.Browser = BrowserView()
        self.dockWidgetBrowser.setWidget(self.Browser)

        self.scrollArea = QScrollArea(self.frame)
        self.gridlayout1.addWidget(self.scrollArea,0,0,1,1)
        self.gridlayout1.setMargin(0)
        self.gridlayout1.setSpacing(0)
        self.gridlayout.addWidget(self.frame,0,0,1,1)

        self.scrollArea.setWidgetResizable(True)
        self.scrollArea.setFrameShape(QFrame.StyledPanel)
        self.scrollArea.setFrameShadow(QFrame.Raised)
        self.scrollArea.setFrameStyle(QFrame.NoFrame)

        # connections

        self.connect(self.fileOpenAction,   SIGNAL("activated()"),   self.fileOpen)
        self.connect(self.fileNewAction,    SIGNAL("activated()"),   self.fileNew)
        self.connect(self.menuRecent,       SIGNAL("aboutToShow()"), self.updateRecentFileMenu)
        self.connect(self.fileSaveAction,   SIGNAL("activated()"),   self.fileSave)
        self.connect(self.fileSaveAsAction, SIGNAL("activated()"),   self.fileSaveAs)
        self.connect(self.fileCloseAction,  SIGNAL("activated()"),   self.close)
        self.connect(self.fileQuitAction,   SIGNAL("activated()"),   self.fileQuit)

        self.connect(self.openXtermAction,      SIGNAL("activated()"), self.openXterm)
        self.connect(self.displayCaseAction,    SIGNAL("activated()"), self.displayCase)
        self.connect(self.reload_modulesAction, SIGNAL("activated()"), self.reload_modules)
        self.connect(self.reload_pageAction,    SIGNAL("activated()"), self.reload_page)

        self.connect(self.IdentityAction, SIGNAL("toggled(bool)"), self.dockWidgetIdentityDisplay)
        self.connect(self.BrowserAction,  SIGNAL("toggled(bool)"), self.dockWidgetBrowserDisplay)

        self.connect(self.displayAboutAction,    SIGNAL("activated()"), self.displayAbout)
        self.connect(self.backgroundColorAction, SIGNAL("activated()"), self.setColor)
        self.connect(self.actionFont,            SIGNAL("activated()"), self.setFontSize)

        self.connect(self.displayLicenceAction,   SIGNAL("activated()"), self.displayLicence)
        #self.connect(self.displayConfigAction,   SIGNAL("activated()"), self.displayConfig)
        self.connect(self.displayCSManualAction,  SIGNAL("activated()"), self.displayCSManual)
        self.connect(self.displayCSTutorialAction, SIGNAL("activated()"), self.displayCSTutorial)
        self.connect(self.displayCSKernelAction,  SIGNAL("activated()"), self.displayCSKernel)
        self.connect(self.displayCSRefcardAction,  SIGNAL("activated()"), self.displayCSRefcard)

        # connection for page layout

        self.connect(self.Browser.treeView, SIGNAL("pressed(const QModelIndex &)"), self.displayNewPage)
        self.connect(self, SIGNAL("destroyed(QObject*)"), MainView.updateInstances)

        # Ctrl+C signal handler (allow to shutdown the GUI with Ctrl+C)

        signal.signal(signal.SIGINT, signal.SIG_DFL)

        # create some instance variables

        self.cmd_case    = cmd_case
        self.salome      = cmd_salome
        self.batch_type  = cs_batch_type
        self.batch       = cmd_batch_window
        self.batch_file  = cmd_batch_file
        self.batch_lines = []
        self.tree_w      = cmd_tree_window
        self.read_o      = cmd_read_only
        self.notree      = 0
        self.package     = package

        self.resize(800, 700)
        #self.setMaximumSize(QSize(2000, 900))

        # restore system settings

        settings = QSettings()
        self.recentFiles = settings.value("RecentFiles").toStringList()
        self.restoreGeometry(
                settings.value("MainWindow/Geometry").toByteArray())
        self.restoreState(
                settings.value("MainWindow/State").toByteArray())

        color = settings.value("MainWindow/Color",
                  QVariant(self.palette().color(QPalette.Window).name()))
        color = QColor(color.toString())
        if color.isValid():
            self.setPalette(QPalette(color))
            app = QCoreApplication.instance()
            app.setPalette(QPalette(color))

        f = settings.value("MainWindow/Font",
                           QVariant(self.font().toString()))
        if (f.isValid()):
            font = QFont()
            if (font.fromString(f.toString())):
                self.setFont(font)
                app = QCoreApplication.instance()
                app.setFont(font)

        title = self.tr("Code_Saturne GUI")
        self.setWindowTitle(title)
        self.updateRecentFileMenu()
        QTimer.singleShot(0, self.loadInitialFile)

        self.statusbar.setSizeGripEnabled(False)
        self.statusbar.showMessage(self.tr("Ready"), 5000)
#        self.setMaximumSize(QSize(700, 600))
#        self.setMinimumSize(QSize(700, 600))


    @staticmethod
    def updateInstances(qobj):
        """
        Overwrites the Instances set with a set that contains only those
        window instances that are still alive.
        """
        MainView.Instances = set([window for window \
                in MainView.Instances if isAlive(window)])


    def loadInitialFile(self):
        """
        Private method.

        Checks the opening mode (from command line).
        """
        log.debug("loadInitialFile -> %s" % self.cmd_case)

        # 1) new case

        if self.cmd_case == "new case":
            MainView.NextId += 1
            self.fileNew()
            self.dockWidgetBrowserDisplay(True)

        # 2) existing case

        elif self.cmd_case:
            try:
                self.loadFile(self.cmd_case)
                self.dockWidgetBrowserDisplay(True)
            except:
                raise

        # 3) neutral point (default page layout)

        else:
            self.displayWelcomePage()
            self.dockWidgetBrowserDisplay(False)


    @pyqtSignature("bool")
    def dockWidgetIdentityDisplay(self, bool=True):
        """
        Private slot.

        Show or hide the  the identity dock window.

        @type bool: C{True} or C{False}
        @param bool: if C{True}, shows the identity dock window
        """
        if bool:
            self.dockWidgetIdentity.show()
        else:
            self.dockWidgetIdentity.hide()


    @pyqtSignature("bool")
    def dockWidgetBrowserDisplay(self, bool=True):
        """
        Private slot.

        Show or hide the browser dock window.

        @type bool: C{True} or C{False}
        @param bool: if C{True}, shows the browser dock window
        """
        if bool:
            self.dockWidgetBrowser.show()
        else:
            self.dockWidgetBrowser.hide()


    @pyqtSignature("")
    def updateRecentFileMenu(self):
        """
        private method

        update the File menu with the recent files list
        """
        self.menuRecent.clear()

        if hasattr(self, 'case'):
            current = QString(self.case['xmlfile'])
        else:
            current = QString()

        recentFiles = []
        for f in self.recentFiles:
            if f != current and QFile.exists(f):
                recentFiles.append(f)

        if recentFiles:
            for i, f in enumerate(recentFiles):
                action = QAction(QIcon(":/icons/22x22/document-open.png"), "&%d %s" % (
                           i + 1, QFileInfo(f).fileName()), self)
                action.setData(QVariant(f))
                self.connect(action,
                             SIGNAL("triggered()"),
                             self.loadRecentFile)
                self.menuRecent.addAction(action)


    def addRecentFile(self, fname):
        """
        private method

        creates and update the list of the recent files

        @type fname: C{str}
        @param fname: filename to add in the recent files list
        """
        if fname is None:
            return
        if not self.recentFiles.contains(fname):
            self.recentFiles.prepend(QString(fname))
            while self.recentFiles.count() > 9:
                self.recentFiles.takeLast()


    def initializeBatchRunningWindow(self):
        """
        initializes variables concerning the display of batchrunning
        """
        self.IdPthMdl = IdentityAndPathesModel(self.case)
        fic = self.IdPthMdl.getXmlFileName()

        if not fic:
            file_name = os.getcwd()
            if os.path.basename(f) == 'DATA': file_name = os.path.dirname(file_name)
            self.IdPthMdl.setCasePath(file_name)
        else:
            file_dir = os.path.split(fic)[0]
            if file_dir:
                self.IdPthMdl.setCasePath(os.path.split(file_dir)[0])
                if not os.path.basename(file_dir) == 'DATA':
                    self.IdPthMdl.setCasePath(file_dir)
            else:
                file_dir = os.path.split(os.getcwd())[0]
                self.IdPthMdl.setCasePath(file_dir)

        for p, rep in [('data_path',     'DATA'),
                       ('resu_path',     'RESU'),
                       ('user_src_path', 'SRC'),
                       ('scripts_path',  'SCRIPTS')]:
            self.IdPthMdl.setPathI(p,file_dir + '/' + rep)
        self.IdPthMdl.setRelevantSubdir("yes", "")

        self.IdPthMdl.setPathI('mesh_path',
                               os.path.abspath(os.path.split(file_dir)[0] + '/' + 'MESH'))
        self.case['batch'] =  self.batch_file
        del IdentityAndPathesModel

        self.updateStudyId()


    def closeEvent(self, event):
        """
        public slot

        try to quit all the current MainWindow
        """
        if self.okToContinue():
            settings = QSettings()
            if self.recentFiles:
                recentFiles = QVariant(self.recentFiles)
            else:
                recentFiles = QVariant()
            #recentFiles = QVariant(self.recentFiles) \
            #        if self.recentFiles else QVariant()
            settings.setValue("RecentFiles", recentFiles)
            settings.setValue("MainWindow/Geometry",
                    QVariant(self.saveGeometry()))
            settings.setValue("MainWindow/State",
                    QVariant(self.saveState()))
            settings.setValue("MainWindow/Color",
                    QVariant(self.palette().color(QPalette.Window).name()))
            settings.setValue("MainWindow/Font",
                    QVariant(self.font().toString()))

            event.accept()
            log.debug("closeEvent -> accept")

        else:
            event.ignore()
            log.debug("closeEvent -> ignore")


    def okToContinue(self):
        """
        private method

        ask for unsaved changes before quit

        @return: C{True} or C{False}
        """
        title = self.tr("Quit")
        msg   = self.tr("Save unsaved changes?")

        if hasattr(self, 'case'):
            log.debug("okToContinue -> %s" % self.case.isModified())

        if hasattr(self, 'case') and self.case.isModified():
            reply = QMessageBox.question(self,
                                         title,
                                         msg,
                                         QMessageBox.Yes|
                                         QMessageBox.No|
                                         QMessageBox.Cancel)
            if reply == QMessageBox.Cancel:
                return False
            elif reply == QMessageBox.Yes:
                self.fileSave()

        return True


    @pyqtSignature("")
    def fileQuit(self):
        """
        Public slot.

        try to quit all window
        """
        QApplication.closeAllWindows()


    @pyqtSignature("")
    def fileNew(self):
        """
        Public slot.

        create new Code_Saturne case
        """
        if not hasattr(self, 'case'):
            self.case = XMLengine.Case(package=self.package)
            self.case.root()['version'] = XML_DOC_VERSION
            XMLinit(self.case)
            title = self.tr("New parameters set") + " - " + self.tr(self.package.code_name) + self.tr(" GUI")
            self.setWindowTitle(title)

            self.Browser.configureTree(self.case)
            self.dockWidgetBrowserDisplay(True)

            self.case['salome'] = self.salome

            p = displaySelectedPage('Identity and paths',
                                    self,
                                    self.case,
                                    stbar=self.statusbar,
                                    study=self.Id,
                                    tree=self.Browser)
            self.scrollArea.setWidget(p)

            self.case['saved'] = "yes"

        else:
            MainView(package=self.package, cmd_case="new case").show()


    def fileAlreadyLoaded(self, f):
        """
        private method

        check if the file to load is not already loaded

        @type fname: C{str}
        @param fname: file name to load
        @return: C{True} or C{False}
        """
        for win in MainView.Instances:
            if isAlive(win) and hasattr(win, 'case') \
               and win.case['xmlfile'] == f:
                win.activateWindow()
                win.raise_()
                return True
        return False


    def loadRecentFile(self, file_name=None):
        """
        private slot

        reload an existing recent file

        @type fname: C{str}
        @param fname: file name to load
        """
        # reload  from File menu
        if file_name is None:
            action = self.sender()
            if isinstance(action, QAction):
                file_name = unicode(action.data().toString())
                if not self.okToContinue():
                    return
            else:
                return

        # check if the file to load is not already loaded
        if hasattr(self, 'case'):
            if not self.fileAlreadyLoaded(file_name):
                MainView(package=self.package, cmd_case = file_name).show()
        else:
            self.loadFile(file_name)


    def loadFile(self, file_name=None):
        """
        Private method

        Load an existing file.

        @type fname: C{str}
        @param fname: file name to load
        """
        #file_name = unicode(file_name)
        file_name = os.path.abspath(str(file_name))
        fn = os.path.basename(file_name)
        log.debug("loadFile -> %s" % file_name)

        # Instantiate a new case

        try:
            self.case = XMLengine.Case(package=self.package, file_name=file_name)
        except:
            err = QErrorMessage(self)
            msg = self.tr("XML file reading error. "\
                          "This file is not in accordance with XML "\
                          "specifications. Please correct it and verify "\
                          "it with XMLcheck tool.")
            err.showMessage(msg)
            if hasattr(self, 'case'):
                delattr(self, 'case')
            return

        self.addRecentFile(fn)

        # Cleaning the '\n' and '\t' from file_name (except in formula)
        self.case.xmlCleanAllBlank(self.case.xmlRootNode())

        try:
            XMLinit(self.case)
        except:
            err = QErrorMessage(self)
            msg = self.tr("XML file reading error. "\
                          "Perhaps the version of the file is to old.")
            err.showMessage(msg)
            if hasattr(self, 'case'):
                delattr(self, 'case')
            return

        self.Browser.configureTree(self.case)
        self.dockWidgetBrowserDisplay(True)

        self.case['salome'] = self.salome

        # Update the case and the StudyIdBar
        self.case['xmlfile'] = file_name
        title = fn + " - " + self.tr(self.package.code_name) + self.tr(" GUI")
        self.setWindowTitle(title)

        msg = self.tr("Loaded: %s" % fn)
        self.statusbar.showMessage(msg, 2000)

        p = displaySelectedPage('Identity and paths',
                                self,
                                self.case,
                                stbar=self.statusbar,
                                study=self.Id,
                                tree=self.Browser)
        self.scrollArea.setWidget(p)

        self.case['saved'] = "yes"

        # Update the Tree Navigator layout

        if self.batch == True:
            self.initializeBatchRunningWindow()
            self.currentEntry = 'Prepare batch calculation'


    @pyqtSignature("")
    def fileOpen(self):
        """
        public slot

        open an existing file
        """
        msg = self.tr("Opening an existing case.")
        self.statusbar.showMessage(msg, 2000)

        title = self.tr("Open existing file.")

        if hasattr(self, 'case') and os.path.isdir(self.case['data_path']):
            path = self.case['data_path']
        else:
            path = os.getcwd()
            if os.path.isdir(path + "/../DATA"): path = path + "/../DATA"

        filetypes = self.tr(self.package.code_name) + self.tr(" GUI files (*.xml);;""All Files (*)")

        file_name = QFileDialog.getOpenFileName(self, title, path, filetypes)

        if file_name.isEmpty() or file_name.isNull():
            msg = self.tr("Loading aborted")
            self.statusbar.showMessage(msg, 2000)
            file_name = None
            return
        else:
            #file_name = unicode(file_name)
            file_name = str(file_name)
            log.debug("fileOpen -> %s" % file_name)

        if hasattr(self, 'case'):
            if not self.fileAlreadyLoaded(file_name):
                MainView(package=self.package, cmd_case = file_name).show()
        else:
            self.loadFile(file_name)

        self.statusbar.clearMessage()


    @pyqtSignature("")
    def openXterm(self):
        """
        public slot

        open an xterm window
        """
        if hasattr(self, 'case'):
            os.system('cd  ' + self.case['case_path'] + ' && xterm -sb &')
        else:
            os.system('xterm -sb&')


    @pyqtSignature("")
    def displayCase(self):
        """
        public slot

        print the case (xml file) on the current terminal
        """
        if hasattr(self, 'case'):
            print(self.case)


    def updateStudyId(self):
        """
        private method

        update the Study Identity dock widget
        """
        study     = self.case.root().xmlGetAttribute('study')
        case      = self.case.root().xmlGetAttribute('case')
        file_name = XMLengine._encode(self.case['xmlfile'])
        self.Id.setStudyName(study)
        self.Id.setCaseName(case)
        self.Id.setXMLFileName(file_name)


    @pyqtSignature("")
    def fileSave(self):
        """
        public slot

        save the current case
        """
        log.debug("fileSave()")

        if not hasattr(self, 'case'):
            return

        file_name = self.case['xmlfile']
        log.debug("fileSave(): %s" % file_name)
        if not file_name:
            self.fileSaveAs()
            return

        log.debug("fileSave(): %s" % os.path.dirname(file_name))
        log.debug("fileSave(): %s" % os.access(os.path.dirname(file_name), os.W_OK))
        if not os.access(os.path.dirname(file_name), os.W_OK):
            title = self.tr("Save error")
            msg   = self.tr("Failed to write %s " % file_name)
            QMessageBox.critical(self, title, msg)
            msg = self.tr("Saving aborted")
            self.statusbar.showMessage(msg, 2000)
            return

        self.updateStudyId()
        self.case.xmlSaveDocument()
        self.batchFileSave()

        log.debug("fileSave(): ok")

        if self.case['batch'] and self.batch_lines:
            batch = self.case['scripts_path'] + "/" + self.case['batch']
            f = open(batch, 'w')
            f.writelines(self.batch_lines)
            f.close()

        msg = self.tr("%s saved" % file_name)
        self.statusbar.showMessage(msg, 2000)


    @pyqtSignature("")
    def fileSaveAs(self):
        """
        public slot

        save the current case with a new name
        """
        log.debug("fileSaveAs()")

        if hasattr(self,'case'):
            filetypes = self.tr(self.package.code_name) + self.tr(" GUI files (*.xml);;""All Files (*)")
            fname = QFileDialog.getSaveFileName(self,
                                  self.tr("Save File As"),
                                  self.case['data_path'],
                                  filetypes)

            if not fname.isEmpty():
                f = str(fname)
                self.case['xmlfile'] = f
                self.addRecentFile(f)
                self.fileSave()
                self.updateStudyId()
                self.case.xmlSaveDocument()
                self.batchFileSave()
                title = os.path.basename(self.case['xmlfile']) + " - " + self.tr(self.package.code_name) + self.tr(" GUI")
                self.setWindowTitle(title)

            else:
                msg = self.tr("Saving aborted")
                self.statusbar.showMessage(msg, 2000)


    def batchFileUpdate(self):
        """
        Update the run command
        """
        cmd_name = self.case['package'].name
        parameters = os.path.basename(self.case['xmlfile'])
        batch_lines = self.batch_lines

        # If filename has whitespace, protect it
        if parameters.find(' ') > -1:
            parameters = '"' + parameters + '"'

        for i in range(len(batch_lines)):
            if batch_lines[i][0:1] != '#':
                line = batch_lines[i].strip()
                index = string.find(line, cmd_name)
                if index < 0:
                    continue
                if line[index + len(cmd_name):].strip()[0:3] != 'run':
                    continue
                index = string.find(line, '--param')
                if index >= 0:
                    # Find file name, possibly protected by quotes
                    # (protection by escape character not handled)
                    index += len('--param')
                    end = len(line)
                    while index < end and line[index] in (' ', '\t'):
                        index += 1
                    if index < end:
                        sep = line[index]
                        if sep == '"' or sep == "'":
                            index += 1
                        else:
                            sep = ' '
                        start = index
                        while index < end and line[index] != sep:
                            index += 1
                        end = index
                        batch_lines[i] = line[0:start].strip() \
                            + ' ' + parameters + ' ' + line[end:].strip() + '\n'
                    else:
                        batch_lines[i] = line + ' --param ' + parameters + '\n'
                else:
                    batch_lines[i] = line + ' --param ' + parameters + '\n'

        self.batch_lines = batch_lines


    @pyqtSignature("")
    def batchFileSave(self):
        """
        public slot

        save the current case
        """
        log.debug("batchFileSave()")

        if not hasattr(self, 'case'):
            return

        if self.case['batch'] and self.batch_lines:

            self.batchFileUpdate()

            batch = self.case['scripts_path'] + "/" + self.case['batch']
            f = open(batch, 'w')
            f.writelines(self.batch_lines)
            f.close()


    @pyqtSignature("")
    def reload_modules(self):
        """
        public slot

        reload all the currently loaded modules, and then update the GUI
        """
        log.debug("reload_modules()")
        title = self.tr("Warning")
        msg = self.tr("This reloads all the currently loaded modules. "\
                      "This is a feature useful only for developers.  You might "\
                      "see funny behaviour for already instantiated objects.\n\n"\
                      "Are you sure you want to do this?")

        ans = QMessageBox.question(self, title, msg,
                                   QMessageBox.Yes|
                                   QMessageBox.No)

        if ans == QMessageBox.Yes:
            self.scrollArea.widget().close()
            reload_all_modules()
            p = displaySelectedPage(self.case['currentPage'],
                                    self,
                                    self.case,
                                    stbar=self.statusbar,
                                    study=self.Id,
                                    tree=self.Browser)
            self.scrollArea.setWidget(p)


    @pyqtSignature("")
    def reload_page(self):
        """
        public slot

        reload the current loaded page
        """
        log.debug("reload_page()")
        title = self.tr("Warning")
        msg = self.tr("This reloads all the current loaded page. "\
                      "This is a feature useful only for developers. You might "\
                      "see funny behaviour for already instantiated objects.\n\n"\
                      "Are you sure you want to do this?")

        ans = QMessageBox.question(self, title, msg,
                                   QMessageBox.Yes|
                                   QMessageBox.No)

        if ans == QMessageBox.Yes:
            self.scrollArea.widget().close()
            reload_current_page()
            p = displaySelectedPage(self.case['currentPage'],
                                    self,
                                    self.case,
                                    stbar=self.statusbar,
                                    study=self.Id,
                                    tree=self.Browser)
            self.scrollArea.setWidget(p)


    @pyqtSignature("")
    def displayAbout(self):
        """
        public slot

        the About dialog window shows:
         - title
         - version
         - contact
        """
        msg = self.package.code_name + "\n"                      +\
              "version " + self.package.version + "\n\n"    +\
              "For information about this application "  +\
              "please contact:\n\n"                      +\
              self.package.bugreport + "\n\n"               +\
              "Please visit our site:\n"                 +\
              self.package.url
        QMessageBox.about(self, self.package.name + ' Interface', msg)


    @pyqtSignature("")
    def displayLicence(self):
        """
        public slot

        GNU GPL license dialog window
        """
        QMessageBox.about(self, self.package.code_name + ' Interface', "see COPYING file") # TODO


    @pyqtSignature("")
    def displayConfig(self):
        """
        public slot

        configuration information window
        """
        QMessageBox.about(self, self.package.code_name + ' Interface', "see config.py") # TODO


    def displayManual(self, manual, reader = None):
        """
        private method

        open a manual
        """
        try:
            import cs_info
        except:
            QMessageBox.warning(self, self.package.code_name + ' Interface',
                                "The module 'cs_info' is not available.")
            return
        argv_info = ['--guide']
        argv_info.append(manual)
        cs_info.main(argv_info, self.package)


    @pyqtSignature("")
    def displayCSManual(self):
        """
        public slot

        open the user manual
        """
        self.displayManual('user')


    @pyqtSignature("")
    def displayCSTutorial(self):
        """
        public slot

        open the tutorial for Code_Saturne
        """
        self.displayManual('tutorial')


    @pyqtSignature("")
    def displayCSKernel(self):
        """
        public slot

        open the theory and programmer's guide
        """
        self.displayManual('theory')


    @pyqtSignature("")
    def displayCSRefcard(self):
        """
        public slot

        open the quick reference card for Code_Saturne
        """
        self.displayManual('refcard')


    @pyqtSignature("const QModelIndex &")
    def displayNewPage(self, index):
        """
        private slot

        display a new page when the Browser send the order

        @type index: C{QModelIndex}
        @param index: index of the item in the C{QTreeView} clicked in the browser
        """
        # stop if the entry is a folder or a file

        if self.Browser.isFolder(): return

        # warning and stop if is no case
        if not hasattr(self, 'case'):
            log.debug("displayNewPage(): no attr. 'case', return ")

            msg = self.tr("You have to create a new case or load\n"\
                          "an existing case before selecting an item")
            w = QMessageBox(self)
            w.information(self,
                          self.tr("Warning"),
                          msg,
                          self.tr('OK'))
            return

        self.page = self.Browser.display(self,
                                         self.case,
                                         self.statusbar,
                                         self.Id,
                                         self.Browser)

        if self.page is not None:
            #self.page.resize(600,500)
            self.scrollArea.setWidget(self.page)

        else:
            log.debug("displayNewPage() self.page == None")
            raise


    def displayWelcomePage(self):
        """
        private method

        display the Welcome (and the default) page
        """
        self.page = WelcomeView()
        #self.page.resize(600,500)
        self.scrollArea.setWidget(self.page)
        #self.gridlayout2.addWidget(self.page, 0, 0)


    @pyqtSignature("")
    def setColor(self):
        """
        public slot

        choose GUI color
        """
        c = self.palette().color(QPalette.Window)
        color = QColorDialog.getColor(c, self)
        if color.isValid():
            self.setPalette(QPalette(color))
            app = QCoreApplication.instance()
            app.setPalette(QPalette(color))


    @pyqtSignature("")
    def setFontSize(self):
        """
        public slot

        choose GUI font
        """
        font, ok = QFontDialog.getFont(self)
        log.debug("setFont -> %s" % ok)
        if ok:
            self.setFont(font)
            app = QCoreApplication.instance()
            app.setFont(font)


    def tr(self, text):
        """
        private method

        translation

        @param text: text to translate
        @return: translated text
        """
        return text


def isAlive(qobj):
    """
    return True if the object qobj exist

    @param qobj: the name of the attribute
    @return: C{True} or C{False}
    """
    import sip
    try:
        sip.unwrapinstance(qobj)
    except RuntimeError:
        return False
    return True


#-------------------------------------------------------------------------------
# Local main program
#-------------------------------------------------------------------------------

if __name__ == "__main__":
    app = QApplication(sys.argv)
    Main = MainView()
    Main.show()
    sys.exit(app.exec_())
