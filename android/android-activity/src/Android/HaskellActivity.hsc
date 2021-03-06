{-# LANGUAGE ForeignFunctionInterface #-}
module Android.HaskellActivity
  ( ActivityCallbacks (..)
  , HaskellActivity (..)
  , getHaskellActivity
  , continueWithCallbacks
  , traceActivityCallbacks
  ) where

import Control.Exception
import Data.Default
import Data.Monoid
import Debug.Trace
import Foreign.C.String
import Foreign.Marshal.Utils
import Foreign.Ptr
import Foreign.Storable

#include "HaskellActivity.h"

newtype HaskellActivity = HaskellActivity { unHaskellActivity :: Ptr HaskellActivity }

foreign import ccall unsafe "HaskellActivity_get" getHaskellActivity :: IO HaskellActivity

-- | Allow the HaskellActivity to proceed.  The given callbacks will be invoked
-- at the appropriate times in the Android Activity lifecycle.
-- WARNING: This should only be invoked once per application execution.
continueWithCallbacks :: ActivityCallbacks -> IO ()
continueWithCallbacks ac = do
  continueWithCallbacks_ =<< new =<< activityCallbacksToPtrs ac

foreign import ccall safe "HaskellActivity_continueWithCallbacks" continueWithCallbacks_ :: Ptr ActivityCallbacksPtrs -> IO ()

data ActivityCallbacks = ActivityCallbacks
  { _activityCallbacks_onCreate :: () -> IO () -- The () input here will eventually become a representation of the Bundle that Android passes in; this placeholder is to make the change easier
  , _activityCallbacks_onStart :: IO ()
  , _activityCallbacks_onResume :: IO ()
  , _activityCallbacks_onPause :: IO ()
  , _activityCallbacks_onStop :: IO ()
  , _activityCallbacks_onDestroy :: IO ()
  , _activityCallbacks_onRestart :: IO ()
  , _activityCallbacks_onNewIntent :: String -> String -> IO ()
  }

instance Default ActivityCallbacks where
  def = ActivityCallbacks
    { _activityCallbacks_onCreate = \_ -> return ()
    , _activityCallbacks_onStart = return ()
    , _activityCallbacks_onResume = return ()
    , _activityCallbacks_onPause = return ()
    , _activityCallbacks_onStop = return ()
    , _activityCallbacks_onDestroy = return ()
    , _activityCallbacks_onRestart = return ()
    , _activityCallbacks_onNewIntent = \_ _ -> return ()
    }

traceBracket :: String -> IO a -> IO a
traceBracket s = bracket (traceIO $ s <> " entered") (\_ -> traceIO $ s <> " exited") . const

traceActivityCallbacks :: ActivityCallbacks -> ActivityCallbacks
traceActivityCallbacks ac = ActivityCallbacks
  { _activityCallbacks_onCreate = \x -> traceBracket "onCreate" $ _activityCallbacks_onCreate ac x
  , _activityCallbacks_onStart = traceBracket "onStart" $ _activityCallbacks_onStart ac
  , _activityCallbacks_onResume = traceBracket "onResume" $ _activityCallbacks_onResume ac
  , _activityCallbacks_onPause = traceBracket "onPause" $ _activityCallbacks_onPause ac
  , _activityCallbacks_onStop = traceBracket "onStop" $ _activityCallbacks_onStop ac
  , _activityCallbacks_onDestroy = traceBracket "onDestroy" $ _activityCallbacks_onDestroy ac
  , _activityCallbacks_onRestart = traceBracket "onRestart" $ _activityCallbacks_onRestart ac
  , _activityCallbacks_onNewIntent = \x y -> traceBracket "onNewIntent" $ _activityCallbacks_onNewIntent ac x y
  }

foreign import ccall "wrapper" wrapIO :: IO () -> IO (FunPtr (IO ()))

foreign import ccall "wrapper" wrapCStringCStringIO :: (CString -> CString -> IO ()) -> IO (FunPtr (CString -> CString -> IO ()))

activityCallbacksToPtrs :: ActivityCallbacks -> IO ActivityCallbacksPtrs
activityCallbacksToPtrs ac = ActivityCallbacksPtrs
  <$> wrapIO (_activityCallbacks_onCreate ac ())
  <*> wrapIO (_activityCallbacks_onStart ac)
  <*> wrapIO (_activityCallbacks_onResume ac)
  <*> wrapIO (_activityCallbacks_onPause ac)
  <*> wrapIO (_activityCallbacks_onStop ac)
  <*> wrapIO (_activityCallbacks_onDestroy ac)
  <*> wrapIO (_activityCallbacks_onRestart ac)
  <*> wrapCStringCStringIO (\a b -> do
                               a' <- peekCString a
                               b' <- peekCString b
                               _activityCallbacks_onNewIntent ac a' b')

data ActivityCallbacksPtrs = ActivityCallbacksPtrs
  { _activityCallbacksPtrs_onCreate :: FunPtr (IO ())
  , _activityCallbacksPtrs_onStart :: FunPtr (IO ())
  , _activityCallbacksPtrs_onResume :: FunPtr (IO ())
  , _activityCallbacksPtrs_onPause :: FunPtr (IO ())
  , _activityCallbacksPtrs_onStop :: FunPtr (IO ())
  , _activityCallbacksPtrs_onDestroy :: FunPtr (IO ())
  , _activityCallbacksPtrs_onRestart :: FunPtr (IO ())
  , _activityCallbacksPtrs_onNewIntent :: FunPtr (CString -> CString -> IO ())
  }

instance Storable ActivityCallbacksPtrs where
  sizeOf _ = #{size ActivityCallbacks}
  alignment _ = #{alignment ActivityCallbacks}
  poke p ac = do
    #{poke ActivityCallbacks, onCreate} p $ _activityCallbacksPtrs_onCreate ac
    #{poke ActivityCallbacks, onStart} p $ _activityCallbacksPtrs_onStart ac
    #{poke ActivityCallbacks, onResume} p $ _activityCallbacksPtrs_onResume ac
    #{poke ActivityCallbacks, onPause} p $ _activityCallbacksPtrs_onPause ac
    #{poke ActivityCallbacks, onStop} p $ _activityCallbacksPtrs_onStop ac
    #{poke ActivityCallbacks, onDestroy} p $ _activityCallbacksPtrs_onDestroy ac
    #{poke ActivityCallbacks, onRestart} p $ _activityCallbacksPtrs_onRestart ac
    #{poke ActivityCallbacks, onNewIntent} p $ _activityCallbacksPtrs_onNewIntent ac
  peek p = ActivityCallbacksPtrs
    <$> #{peek ActivityCallbacks, onCreate} p
    <*> #{peek ActivityCallbacks, onStart} p
    <*> #{peek ActivityCallbacks, onResume} p
    <*> #{peek ActivityCallbacks, onPause} p
    <*> #{peek ActivityCallbacks, onStop} p
    <*> #{peek ActivityCallbacks, onDestroy} p
    <*> #{peek ActivityCallbacks, onRestart} p
    <*> #{peek ActivityCallbacks, onNewIntent} p
