module TurboHaskell.ValidationSupport.ValidateFieldIO (validateFieldIO) where

import           ClassyPrelude
import           Control.Lens                         hiding ((|>))
import           Data.Generics.Product
import           Data.Generics.Product.Types
import           Data.Proxy
import qualified Data.Text                            as Text
import qualified Data.UUID
import qualified Database.PostgreSQL.Simple           as PG
import qualified Database.PostgreSQL.Simple.ToField as PG
import           TurboHaskell.AuthSupport.Authorization
import           TurboHaskell.ModelSupport
import           TurboHaskell.NameSupport               (humanize)
import           TurboHaskell.QueryBuilder              (Fetchable, fetchOneOrNothing)
import           TurboHaskell.ValidationSupport.Types
import           GHC.Generics
import           GHC.Records                          hiding (HasField, getField)
import           GHC.TypeLits                         (KnownSymbol, Symbol)
import Control.Monad.State
import TurboHaskell.HaskellSupport hiding (get)
import TurboHaskell.QueryBuilder

type CustomIOValidation value = value -> IO ValidatorResult

validateFieldIO :: forall field model savedModel idType validationState fieldValue validationStateValue fetchedModel. (
        ?model :: model
        , savedModel ~ GetModelById (ModelFieldValue model "id")
        , ?modelContext :: ModelContext
        , PG.FromRow savedModel
        , KnownSymbol field
        , HasField' field model fieldValue
        , HasField field (ValidatorResultFor model) (ValidatorResultFor model) ValidatorResult ValidatorResult
        , fieldValue ~ ModelFieldValue savedModel field
        , KnownSymbol (GetTableName savedModel)
        , PG.ToField fieldValue
        , EqOrIsOperator fieldValue
        , Generic model
    ) => Proxy field -> CustomIOValidation fieldValue ->  StateT (ValidatorResultFor model) IO ()
validateFieldIO fieldProxy customValidation = do
    let value :: fieldValue = getField @field ?model
    result <- liftIO (customValidation value)
    case result of
        (Failure _) -> do
            validationState <- get
            put $ validationState & ((field @field) .~ result)
        _ -> return ()
