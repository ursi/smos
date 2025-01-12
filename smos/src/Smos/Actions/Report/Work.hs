{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Smos.Actions.Report.Work where

import Cursor.Map
import Cursor.Simple.List.NonEmpty
import Data.Time
import Lens.Micro
import Path
import Smos.Actions.File
import Smos.Actions.Utils
import Smos.Cursor.Report.Entry
import Smos.Report.Archive
import Smos.Report.Config
import Smos.Report.ShouldPrint
import Smos.Report.Work
import Smos.Types

allPlainReportWorkActions :: [Action]
allPlainReportWorkActions =
  [ reportWork,
    prevWork,
    nextWork,
    firstWork,
    lastWork,
    enterWorkFile,
    selectWorkReport,
    selectWorkFilter,
    removeWorkFilter,
    deleteWorkFilter
  ]

allReportWorkUsingActions :: [ActionUsing Char]
allReportWorkUsingActions =
  [ insertWorkFilter,
    appendWorkFilter
  ]

reportWork :: Action
reportWork =
  Action
    { actionName = "reportWork",
      actionFunc = modifyEditorCursorS $ \ec -> do
        saveCurrentSmosFile
        src <- asks configReportConfig
        now <- liftIO getZonedTime
        wd <- liftIO $ resolveReportWorkflowDir src
        pd <- liftIO $ resolveReportProjectsDir src
        let mpd = stripProperPrefix wd pd
        let dc = smosReportConfigDirectoryConfig src
        let wc = smosReportConfigWorkConfig src
        let wac = smosReportConfigWaitingConfig src
        let sc = smosReportConfigStuckConfig src
        let ctx =
              WorkReportContext
                { workReportContextNow = now,
                  workReportContextProjectsSubdir = mpd,
                  workReportContextBaseFilter = workReportConfigBaseFilter wc,
                  workReportContextCurrentContext = Nothing,
                  workReportContextTimeProperty = workReportConfigTimeProperty wc,
                  workReportContextTime = Nothing,
                  workReportContextAdditionalFilter = Nothing,
                  workReportContextContexts = workReportConfigContexts wc,
                  workReportContextChecks = workReportConfigChecks wc,
                  workReportContextSorter = workReportConfigSorter wc,
                  workReportContextWaitingThreshold = waitingReportConfigThreshold wac,
                  workReportContextStuckThreshold = stuckReportConfigThreshold sc
                }

        wrc <- liftIO $ produceWorkReportCursor HideArchive DontPrint dc ctx
        -- If there are no contexts, we don't care about the entries without context
        let wrc' = if null (workReportConfigContexts wc) then wrc {workReportCursorEntriesWithoutContext = emptyEntryReportCursor} else wrc
        pure $
          ec
            { editorCursorSelection = ReportSelected,
              editorCursorReportCursor = Just $ ReportWork wrc'
            },
      actionDescription = "Work report"
    }

prevWork :: Action
prevWork =
  Action
    { actionName = "prevWork",
      actionFunc = modifyWorkReportCursorM workReportCursorPrev,
      actionDescription = "Select the previous entry in the work report"
    }

nextWork :: Action
nextWork =
  Action
    { actionName = "nextWork",
      actionFunc = modifyWorkReportCursorM workReportCursorNext,
      actionDescription = "Select the next entry in the work report"
    }

firstWork :: Action
firstWork =
  Action
    { actionName = "firstWork",
      actionFunc = modifyWorkReportCursor workReportCursorFirst,
      actionDescription = "Select the first entry in the work report"
    }

lastWork :: Action
lastWork =
  Action
    { actionName = "lastWork",
      actionFunc = modifyWorkReportCursor workReportCursorLast,
      actionDescription = "Select the last entry in the work report"
    }

enterWorkFile :: Action
enterWorkFile =
  Action
    { actionName = "enterWorkFile",
      actionFunc = do
        ss <- get
        case editorCursorReportCursor $ smosStateCursor ss of
          Just rc -> case rc of
            ReportWork wrc -> do
              dc <- asks $ smosReportConfigDirectoryConfig . configReportConfig
              wd <- liftIO $ resolveDirWorkflowDir dc
              let switchToEntryReportEntryCursor ad EntryReportEntryCursor {..} = switchToCursor (ad </> entryReportEntryCursorFilePath) $ Just $ makeSmosFileCursorFromSimpleForestCursor entryReportEntryCursorForestCursor
                  switchToSelectedInEntryReportCursor ad erc =
                    case entryReportCursorBuildSmosFileCursor ad erc of
                      Nothing -> pure ()
                      Just (afp, sfc) -> switchToCursor afp $ Just sfc
              case workReportCursorSelection wrc of
                NextBeginSelected -> case workReportCursorNextBeginCursor wrc of
                  Nothing -> pure ()
                  Just erc -> switchToEntryReportEntryCursor wd erc
                WithoutContextSelected -> switchToSelectedInEntryReportCursor wd (workReportCursorEntriesWithoutContext wrc)
                CheckViolationsSelected -> case workReportCursorCheckViolations wrc of
                  Nothing -> pure ()
                  Just mc ->
                    let kvc = mc ^. mapCursorElemL
                        erc = foldKeyValueCursor (\_ x -> x) (\_ x -> x) kvc
                     in switchToSelectedInEntryReportCursor wd erc
                DeadlinesSelected -> switchToSelectedInEntryReportCursor wd (timestampsReportCursorEntryReportCursor (workReportCursorDeadlinesCursor wrc))
                WaitingSelected -> switchToSelectedInEntryReportCursor wd (waitingReportCursorEntryReportCursor (workReportCursorOverdueWaiting wrc))
                StuckSelected -> case stuckReportCursorSelectedFile (workReportCursorOverdueStuck wrc) of
                  Nothing -> pure ()
                  Just rf -> switchToFile $ wd </> rf
                LimboSelected -> case workReportCursorLimboProjects wrc of
                  Nothing -> pure ()
                  Just nec -> switchToFile $ wd </> nonEmptyCursorCurrent nec
                ResultsSelected -> switchToSelectedInEntryReportCursor wd (workReportCursorResultEntries wrc)
            _ -> pure ()
          Nothing -> pure (),
      actionDescription = "Select the last entry in the work report"
    }

insertWorkFilter :: ActionUsing Char
insertWorkFilter =
  ActionUsing
    { actionUsingName = "insertWorkFilter",
      actionUsingDescription = "Insert a character into the filter bar",
      actionUsingFunc = \a -> modifyWorkReportCursorM $ workReportCursorInsert a
    }

appendWorkFilter :: ActionUsing Char
appendWorkFilter =
  ActionUsing
    { actionUsingName = "appendWorkFilter",
      actionUsingDescription = "Append a character onto the filter bar",
      actionUsingFunc = \a -> modifyWorkReportCursorM $ workReportCursorAppend a
    }

removeWorkFilter :: Action
removeWorkFilter =
  Action
    { actionName = "removeWorkFilter",
      actionDescription = "Remove the character in filter bar before cursor",
      actionFunc = modifyWorkReportCursorM workReportCursorRemove
    }

deleteWorkFilter :: Action
deleteWorkFilter =
  Action
    { actionName = "deleteWorkFilter",
      actionDescription = "Remove the character in filter bar under cursor",
      actionFunc = modifyWorkReportCursorM workReportCursorDelete
    }

selectWorkReport :: Action
selectWorkReport =
  Action
    { actionName = "selectWorkReport",
      actionDescription = "Select the work report",
      actionFunc = modifyWorkReportCursorM workReportCursorSelectReport
    }

selectWorkFilter :: Action
selectWorkFilter =
  Action
    { actionName = "selectWorkFilter",
      actionDescription = "Select the work filter bar",
      actionFunc = modifyWorkReportCursorM workReportCursorSelectFilter
    }
