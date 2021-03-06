{-# LANGUAGE
    OverloadedStrings
  , FlexibleContexts
  , ScopedTypeVariables
  #-}

module App.Implementation.Database where

import           App.Prototype.App              ( HasEnv(..) )
import           Control.Monad.IO.Class         ( MonadIO(..) )
import           Control.Monad.Except           ( MonadError(..), liftEither )
import           Data.Text                      ( Text, pack )
import           Data.Int                       ( Int64 )
import           Control.Exception              ( Handler(..) , catches)
import           Data.Text.Encoding             ( decodeUtf8 )
import           Database.PostgreSQL.Simple     ( FormatError(..)
                                                , QueryError(..)
                                                , ResultError(..)
                                                , SqlError(..)
                                                )
import qualified Database.PostgreSQL.Simple     as DB

newtype DbEnv = DbEnv DB.Connection

postgresqlExecute
  :: (HasEnv DbEnv m, MonadIO m, DB.ToRow q, MonadError Text m)
  => DB.Query
  -> q
  -> m (Either Text Int64)
postgresqlExecute q fq = do
  DbEnv conn <- getEnv
  liftEither =<< liftIO ((Right . Right <$> DB.execute conn q fq) `catches` defaultDbHandlers)

postgresqlQuery
  :: (HasEnv DbEnv m, MonadIO m, DB.ToRow q, DB.FromRow r, MonadError Text m)
  => DB.Query
  -> q
  -> m (Either Text [r])
postgresqlQuery q fq = do
  DbEnv conn <- getEnv
  liftEither =<< liftIO ((Right . Right <$> DB.query conn q fq) `catches` defaultDbHandlers)

defaultDbHandlers :: [Handler (Either Text (Either Text b))]
defaultDbHandlers =
  [ Handler (\(e :: FormatError) -> return . Left . pack $ fmtMessage e )
  , Handler (\(e :: ResultError) -> return . Left . pack $ showResultError e)
  , Handler (\(e :: QueryError)  -> return . Left . pack $ qeMessage e)
  , Handler
    (\(e :: SqlError) -> return . Right . Left . decodeUtf8 $
      sqlErrorMsg e <> " (" <> sqlErrorDetail e <> ") (" <> sqlErrorHint e <> ")"
    )
  ]

showResultError :: ResultError -> String
showResultError (DB.Incompatible     sqlType _ _     hType msg) = "sql incompatible: " <> msg <> " (" <> hType <> " ~ " <> sqlType <> ")"
showResultError (DB.UnexpectedNull   _       _ field _     msg) = "sql unexpected null: " <> msg <> " @ " <> field
showResultError (DB.ConversionFailed sqlType _ _     hType msg) = "sql conversion failed" <> msg <> " (" <> hType <> " ~ " <> sqlType <> ")"
