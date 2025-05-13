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




document.addEventListener('DOMContentLoaded', () => {
  // Create a ResizeObserver to monitor changes in .chart-wrapper elements
  const resizeObserver = new ResizeObserver(entries => {
    entries.forEach(entry => {
      // Within each observed .chart-wrapper, find all canvas elements
      entry.target.querySelectorAll('canvas').forEach(canvas => {
        // Retrieve the Chart instance tied to this canvas
        const chartInstance = Chart.getChart(canvas);
        if (chartInstance) {
          // Resize the chart instance to match the parent container
          chartInstance.resize();
        }
      });
    });
  });

  // Attach the ResizeObserver to every element with the class .chart-wrapper
  document.querySelectorAll('.chart-wrapper').forEach(wrapper => {
    resizeObserver.observe(wrapper);
  });
}); 