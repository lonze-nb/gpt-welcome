const defaultGreeting = "welcome";

function showGreeting(element, greeting) {
  element.textContent = greeting;
  const length = Array.from(greeting).length;
  element.style.setProperty("--greeting-size", Math.min(10, 38 / Math.sqrt(Math.max(length, 1))));
}

function animateGreeting(element, greeting) {
  showGreeting(element, greeting);
  for (const animation of element.getAnimations()) animation.cancel();
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return Promise.resolve();
  }
  const animation = element.animate(
    [{ clipPath: "inset(0 100% 0 0)" }, { clipPath: "inset(0)" }],
    { duration: 2400, easing: "ease-in-out" },
  );
  return animation.finished.catch(() => {});
}
