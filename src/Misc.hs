module Misc where
import           Data.Text(Text,pack)

showText :: Show a => a -> Text
showText = pack . show

