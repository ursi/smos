{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

module Smos.Cursor.Report.Work where

import Conduit
import Cursor.Simple.List.NonEmpty
import qualified Data.Conduit.Combinators as C
import qualified Data.List.NonEmpty as NE
import Data.Time
import Data.Validity
import Data.Validity.Path ()
import GHC.Generics
import Lens.Micro
import Path
import Smos.Cursor.Report.Entry
import Smos.Data
import Smos.Report.Archive
import Smos.Report.Config
import Smos.Report.ShouldPrint
import Smos.Report.Streaming
import Smos.Report.Work

produceWorkReportCursor :: HideArchive -> ShouldPrint -> DirectoryConfig -> WorkReportContext -> IO WorkReportCursor
produceWorkReportCursor ha sp dc wrc = produceReport ha sp dc $ intermediateWorkReportToWorkReportCursor <$> intermediateWorkReportConduit wrc

data WorkReportCursor = WorkReportCursor
  { workReportCursorResultEntries :: !(EntryReportCursor ()),
    workReportCursorSelection :: !WorkReportCursorSelection
  }
  deriving (Show, Eq, Generic)

instance Validity WorkReportCursor

intermediateWorkReportToWorkReportCursor :: IntermediateWorkReport -> WorkReportCursor
intermediateWorkReportToWorkReportCursor IntermediateWorkReport {..} =
  let workReportCursorResultEntries = makeEntryReportCursor $ flip map intermediateWorkReportResultEntries $ \(rf, fc) -> makeEntryReportEntryCursor rf fc ()
      workReportCursorSelection = ResultsSelected
   in WorkReportCursor {..}

data WorkReportCursorSelection = ResultsSelected
  deriving (Show, Eq, Generic)

instance Validity WorkReportCursorSelection

workReportCursorResultEntriesL :: Lens' WorkReportCursor (EntryReportCursor ())
workReportCursorResultEntriesL = lens workReportCursorResultEntries $ \wrc rc -> wrc {workReportCursorResultEntries = rc}

workReportCursorNext :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorNext = workReportCursorResultEntriesL entryReportCursorNext

workReportCursorPrev :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorPrev = workReportCursorResultEntriesL entryReportCursorPrev

workReportCursorFirst :: WorkReportCursor -> WorkReportCursor
workReportCursorFirst = workReportCursorResultEntriesL %~ entryReportCursorFirst

workReportCursorLast :: WorkReportCursor -> WorkReportCursor
workReportCursorLast = workReportCursorResultEntriesL %~ entryReportCursorLast

workReportCursorSelectReport :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorSelectReport = workReportCursorResultEntriesL entryReportCursorSelectReport

workReportCursorSelectFilter :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorSelectFilter = workReportCursorResultEntriesL entryReportCursorSelectFilter

workReportCursorInsert :: Char -> WorkReportCursor -> Maybe WorkReportCursor
workReportCursorInsert c = workReportCursorResultEntriesL $ entryReportCursorInsert c

workReportCursorAppend :: Char -> WorkReportCursor -> Maybe WorkReportCursor
workReportCursorAppend c = workReportCursorResultEntriesL $ entryReportCursorAppend c

workReportCursorRemove :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorRemove = workReportCursorResultEntriesL entryReportCursorRemove

workReportCursorDelete :: WorkReportCursor -> Maybe WorkReportCursor
workReportCursorDelete = workReportCursorResultEntriesL entryReportCursorDelete