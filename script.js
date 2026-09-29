const screens = {
  discover: { file: 'discover.png', alt: 'Discover screen with a synthetic prototype profile', caption: 'Discover • find people who fit your pace' },
  explore: { file: 'explore.png', alt: 'Explore screen from the Vawra prototype', caption: 'Explore • follow what sparks your interest' },
  match: { file: 'match.png', alt: 'Match celebration screen from the Vawra prototype', caption: 'Connect • make a new connection' },
  chat: { file: 'chat.png', alt: 'Chat screen from the Vawra prototype', caption: 'Chat • keep the conversation going' },
};

const tabs = [...document.querySelectorAll('.preview-tab')];
const image = document.querySelector('#preview-image');
const caption = document.querySelector('#screen-caption');
const panel = document.querySelector('#preview-panel');

function selectTab(tab, focus = false) {
  const screen = screens[tab.dataset.screen];
  if (!screen) return;
  for (const item of tabs) {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
  }
  image.src = `assets/screens/raw/${screen.file}`;
  image.alt = screen.alt;
  caption.textContent = screen.caption;
  panel.setAttribute('aria-labelledby', tab.id);
  if (focus) tab.focus();
}

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', (event) => {
    let next = index;
    if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
    else if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = tabs.length - 1;
    else return;
    event.preventDefault();
    selectTab(tabs[next], true);
  });
});

const menu = document.querySelector('.menu-toggle');
const navLinks = document.querySelector('#nav-links');
menu.addEventListener('click', () => {
  const open = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(open));
  menu.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  navLinks.classList.toggle('is-open', open);
});
navLinks.addEventListener('click', (event) => {
  if (!event.target.closest('a')) return;
  menu.setAttribute('aria-expanded', 'false');
  menu.setAttribute('aria-label', 'Open menu');
  navLinks.classList.remove('is-open');
});
document.querySelector('#year').textContent = new Date().getFullYear();
