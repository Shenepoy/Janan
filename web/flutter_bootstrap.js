{{flutter_js}}
{{flutter_build_config}}
// First-frame removal prevents a blank interval while Flutter initializes.
window.addEventListener('flutter-first-frame', () => document.getElementById('janan-boot')?.remove(), {once:true});
function bootFailed() {
  const boot = document.getElementById('janan-boot');
  if (boot) boot.textContent = 'Could not open Janan. Reload to try again. · تعذر فتح الجنان. أعد تحميل الصفحة للمحاولة مجدداً.';
}
_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/'},
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const app = await engineInitializer.initializeEngine();
      await app.runApp();
    } catch (_) { bootFailed(); }
  }
}).catch(bootFailed);
