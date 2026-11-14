{{flutter_js}}
{{flutter_build_config}}

(function () {
  var setStage =
    typeof window.__walnutSetBootStage === 'function'
      ? window.__walnutSetBootStage
      : function () {};

  setStage(0.24, 'Unpacking 1969 Tube Amps & CanvasKit Engine…');

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      setStage(0.58, 'Stringing Lanterns Across Max Yasgur-Shell’s Grove…');
      var appRunner = await engineInitializer.initializeEngine();
      setStage(0.86, 'Tuning 5 Live Stages & 30 Original Sets…');
      await appRunner.runApp();
    },
  });
})();
