//= require chartkick
//= require Chart.bundle
//= require popper
//= require bootstrap 
//= require jquery

const rootStyles = getComputedStyle(document.documentElement);
const esBlack       = rootStyles.getPropertyValue('--es-black').trim();
const esGreenLight  = rootStyles.getPropertyValue('--es-green-light').trim();
const esGreenDark   = rootStyles.getPropertyValue('--es-green-dark').trim();
const esOrangeLight = rootStyles.getPropertyValue('--es-orange-light').trim();
const esOrangeDark  = rootStyles.getPropertyValue('--es-orange-dark').trim();
const esPurple      = rootStyles.getPropertyValue('--es-purple').trim();
const esPurpleLight = rootStyles.getPropertyValue('--es-purple-light').trim();
const esPurpleDark  = rootStyles.getPropertyValue('--es-purple-dark').trim();

// Global style defaults
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.font.size = 14;
Chart.defaults.color = esBlack;