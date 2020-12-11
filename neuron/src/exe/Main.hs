{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Main where

import Control.Monad.Reader
import Development.Shake
import Main.Utf8
import Neuron.CLI (run)
import Neuron.Config.Type (Config)
import Neuron.Version (neuronVersion)
import Neuron.Web.Generate (generateSite)
import Neuron.Web.Generate.Route (staticRouteConfig)
import Neuron.Web.HeadHtml (HeadHtml, getHeadHtml)
import Neuron.Web.Manifest (Manifest)
import qualified Neuron.Web.Manifest as Manifest
import Neuron.Web.Route (NeuronWebT, Route (..), runNeuronWeb)
import Neuron.Web.StructuredData (renderStructuredData)
import Neuron.Web.View (renderRouteBody, renderRouteHead)
import Neuron.Zettelkasten.Graph.Type (ZettelGraph)
import Reflex.Dom.Core
import Reflex.Dom.Pandoc (PandocBuilder)
import Relude
import Rib.Route (writeRoute)
import Rib.Shake (buildStaticFiles, ribInputDir)

main :: IO ()
main = withUtf8 $ run generateMainSite

generateMainSite :: Config -> Action ()
generateMainSite config = do
  notesDir <- ribInputDir
  buildStaticFiles ["static/**", ".nojekyll"]
  manifest <- Manifest.mkManifest <$> getDirectoryFiles notesDir Manifest.manifestPatterns
  headHtml <- getHeadHtml
  let writeHtmlRoute :: Route a -> (ZettelGraph, a) -> Action ()
      writeHtmlRoute r x = do
        html <- liftIO $
          fmap snd $
            renderStatic $ do
              runNeuronWeb staticRouteConfig $
                renderRoutePage config headHtml manifest r x
        -- FIXME: Make rib take bytestrings
        writeRoute r $ decodeUtf8 @Text html
  void $ generateSite config writeHtmlRoute

-- | Render the given route
renderRoutePage ::
  PandocBuilder t m =>
  Config ->
  HeadHtml ->
  Manifest ->
  Route a ->
  (ZettelGraph, a) ->
  NeuronWebT t m ()
renderRoutePage config headHtml manifest r val = do
  -- DOCTYPE declaration is helpful for code that might appear in the user's `head.html` file (e.g. KaTeX).
  el "!DOCTYPE html" blank
  elAttr "html" ("lang" =: "en") $ do
    el "head" $ do
      renderRouteHead config headHtml manifest r (snd val) $ do
        renderStructuredData config r val
    el "body" $ do
      renderRouteBody neuronVersion config r val