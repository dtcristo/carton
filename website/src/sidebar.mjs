// Keep section selection separate from the current document and its URL.
export function initSidebar(root) {
  const buttons = [...root.querySelectorAll('.section-tabs button')];
  const select = (selected) => {
    for (const button of buttons) {
      const active = button === selected;
      button.setAttribute('aria-pressed', String(active));
      root.querySelector(`#${button.getAttribute('aria-controls')}`).hidden = !active;
    }
  };

  select(buttons.find((button) => button.getAttribute('aria-pressed') === 'true') ?? buttons[0]);
  for (const button of buttons) {
    button.addEventListener('click', () => select(button));
  }
  for (const heading of root.querySelectorAll('[data-section-heading]')) heading.hidden = true;
  root.querySelector('.section-tabs').hidden = false;
}
