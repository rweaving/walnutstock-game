{{flutter_js}}
{{flutter_build_config}}

(function () {
  var setStage =
    typeof window.__walnutSetBootStage === 'function'
      ? window.__walnutSetBootStage
      : function () {};

  setStage(0.22, 'Unpacking 1969 Tube Amps & CanvasKit Engine…');

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      setStage(0.52, 'Stringing Dusk Lanterns Across Max Yasgur-Shell’s Grove…');
      var appRunner = await engineInitializer.initializeEngine();
      setStage(0.78, 'Opening the Orchard Gate & Tuning 5 Live Stages…');
      await appRunner.runApp();
    },
  });
})();
