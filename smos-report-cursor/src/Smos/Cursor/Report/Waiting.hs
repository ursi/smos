{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

module Smos.Cursor.Report.Waiting where

import Cursor.Forest
import Data.List
import Data.Maybe
import Data.Time
import Data.Validity
import Data.Validity.Path ()
import GHC.Generics
import Lens.Micro
import Path
import Smos.Cursor.Report.Entry
import Smos.Cursor.SmosFile
import Smos.Data
import Smos.Report.Archive
import Smos.Report.Config
import Smos.Report.Filter
import Smos.Report.ShouldPrint
import Smos.Report.Waiting

produceWaitingReportCursor :: Maybe EntryFilterRel -> HideArchive -> ShouldPrint -> DirectoryConfig -> IO WaitingReportCursor
produceWaitingReportCursor mf ha sp dc =
  WaitingReportCursor <$> produceEntryReportCursor makeWaitingEntryCursor' sortWaitingReport mf ha sp dc

data WaitingReportCursor = WaitingReportCursor
  { waitingReportCursorEntryReportCursor :: EntryReportCursor UTCTime -- The time at which the entry became WAITING
  }
  deriving (Show, Eq, Generic)

instance Validity WaitingReportCursor where
  validate wrc@WaitingReportCursor {..} =
    mconcat
      [ genericValidate wrc,
        declare "The waiting entries are in order" $
          let es = waitingReportCursorEntryReportCursor ^. entryReportCursorEntryReportEntryCursorsL
           in sortWaitingReport es == es
      ]

waitingReportCursorEntryReportCursorL :: Lens' WaitingReportCursor (EntryReportCursor UTCTime)
waitingReportCursorEntryReportCursorL = lens waitingReportCursorEntryReportCursor $ \wrc ne -> wrc {waitingReportCursorEntryReportCursor = ne}

sortWaitingReport :: [EntryReportEntryCursor UTCTime] -> [EntryReportEntryCursor UTCTime]
sortWaitingReport = sortOn entryReportEntryCursorVal

waitingReportCursorBuildSmosFileCursor :: Path Abs Dir -> WaitingReportCursor -> Maybe (Path Abs File, SmosFileCursor)
waitingReportCursorBuildSmosFileCursor ad = entryReportCursorBuildSmosFileCursor ad . waitingReportCursorEntryReportCursor

waitingReportCursorNext :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorNext = waitingReportCursorEntryReportCursorL entryReportCursorNext

waitingReportCursorPrev :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorPrev = waitingReportCursorEntryReportCursorL entryReportCursorPrev

waitingReportCursorFirst :: WaitingReportCursor -> WaitingReportCursor
waitingReportCursorFirst = waitingReportCursorEntryReportCursorL %~ entryReportCursorFirst

waitingReportCursorLast :: WaitingReportCursor -> WaitingReportCursor
waitingReportCursorLast = waitingReportCursorEntryReportCursorL %~ entryReportCursorLast

waitingReportCursorSelectReport :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorSelectReport = waitingReportCursorEntryReportCursorL entryReportCursorSelectReport

waitingReportCursorSelectFilter :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorSelectFilter = waitingReportCursorEntryReportCursorL entryReportCursorSelectFilter

waitingReportCursorInsert :: Char -> WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorInsert c = waitingReportCursorEntryReportCursorL $ entryReportCursorInsert c

waitingReportCursorAppend :: Char -> WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorAppend c = waitingReportCursorEntryReportCursorL $ entryReportCursorAppend c

waitingReportCursorRemove :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorRemove = waitingReportCursorEntryReportCursorL entryReportCursorRemove

waitingReportCursorDelete :: WaitingReportCursor -> Maybe WaitingReportCursor
waitingReportCursorDelete = waitingReportCursorEntryReportCursorL entryReportCursorDelete

makeWaitingEntryCursor' :: Path Rel File -> ForestCursor Entry Entry -> [UTCTime]
makeWaitingEntryCursor' _ = maybeToList . makeWaitingEntryCursor

makeWaitingEntryCursor :: ForestCursor Entry Entry -> Maybe UTCTime
makeWaitingEntryCursor fc = parseWaitingStateTimestamp $ forestCursorCurrent fc
