//= require chartkick
//= require Chart.bundle
//= require popper
//= require bootstrap 
//= require jquery
//= require jquery_ujs
//= require actioncable
//= require collection_sync

const rootStyles = getComputedStyle(document.documentElement);

const esPurple              = rootStyles.getPropertyValue('--es-purple').trim();
const esPurpleLight         = rootStyles.getPropertyValue('--es-purple-light').trim();
const esPurpleDark          = rootStyles.getPropertyValue('--es-purple-dark').trim();
const esPurpleTransparent   = rootStyles.getPropertyValue('--es-purple-transparent').trim();
const esGreen               = rootStyles.getPropertyValue('--es-green').trim();
const esGreenLight          = rootStyles.getPropertyValue('--es-green-light').trim();
const esGreenDark           = rootStyles.getPropertyValue('--es-green-dark').trim();
const esGreenTransparent    = rootStyles.getPropertyValue('--es-green-transparent').trim();
const esOrange              = rootStyles.getPropertyValue('--es-orange').trim();
const esOrangeLight         = rootStyles.getPropertyValue('--es-orange-light').trim();
const esOrangeDark          = rootStyles.getPropertyValue('--es-orange-dark').trim();
const esOrangeTransparent   = rootStyles.getPropertyValue('--es-orange-transparent').trim();
const esBlack               = rootStyles.getPropertyValue('--es-black').trim();

// Global style defaults
Chart.defaults.font.family = "'Inter', sans-serif";
Chart.defaults.font.size = 14;
Chart.defaults.color = esBlack;




// Chart initialization function
function initializeCharts() {
  // Initialize all charts with data attributes
  document.querySelectorAll('[data-chart]').forEach(canvas => {
    // Skip if chart already exists
    if (Chart.getChart(canvas)) {
      return;
    }

    const chartType = canvas.dataset.chart;
    const chartData = JSON.parse(canvas.dataset.chartData || '{}');
    const chartOptions = JSON.parse(canvas.dataset.chartOptions || '{}');

    // Create chart based on type
    switch (chartType) {
      case 'line':
        createLineChart(canvas, chartData, chartOptions);
        break;
      case 'bar':
        createBarChart(canvas, chartData, chartOptions);
        break;
      case 'doughnut':
        createDoughnutChart(canvas, chartData, chartOptions);
        break;
    }
  });
}

// Line chart creation
function createLineChart(canvas, data, options = {}) {
  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: true,
    scales: {
      x: {
        display: true,
        grid: { display: false }
      },
      y: {
        display: false,
        grid: { display: false },
        beginAtZero: false
      }
    },
    plugins: {
      legend: {
        display: false,
        usePointStyle: true
      },
      tooltip: { enabled: true }
    }
  };

  const chartOptions = { ...defaultOptions, ...options };

  new Chart(canvas, {
    type: 'line',
    data: {
      labels: data.labels || [],
      datasets: [{
        label: data.label || 'Data',
        data: data.values || [],
        borderColor: esOrangeDark,
        borderWidth: 3,
        pointRadius: 3,
        tension: 0.4,
        fill: true,
        backgroundColor: esOrangeTransparent,
        ...data.dataset
      }]
    },
    options: chartOptions
  });
}

// Bar chart creation
function createBarChart(canvas, data, options = {}) {
  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: true,
    scales: {
      x: {
        display: true,
        grid: { display: false }
      },
      y: {
        display: false,
        grid: { display: false },
        beginAtZero: true
      }
    },
    plugins: {
      legend: {
        display: false,
        usePointStyle: true
      },
      tooltip: { enabled: true }
    }
  };

  const chartOptions = { ...defaultOptions, ...options };

  new Chart(canvas, {
    type: 'bar',
    data: {
      labels: data.labels || [],
      datasets: [{
        label: data.label || 'Data',
        data: data.values || [],
        backgroundColor: esPurple,
        borderColor: esPurpleDark,
        borderWidth: 1,
        ...data.dataset
      }]
    },
    options: chartOptions
  });
}

// Doughnut chart creation
function createDoughnutChart(canvas, data, options = {}) {
  const defaultOptions = {
    responsive: true,
    maintainAspectRatio: true,
    plugins: {
      legend: {
        display: true,
        position: 'bottom'
      },
      tooltip: { enabled: true }
    }
  };

  const chartOptions = { ...defaultOptions, ...options };

  new Chart(canvas, {
    type: 'doughnut',
    data: {
      labels: data.labels || [],
      datasets: [{
        data: data.values || [],
        backgroundColor: [esPurple, esOrange, esGreen, esPurpleLight, esOrangeLight],
        borderWidth: 2,
        ...data.dataset
      }]
    },
    options: chartOptions
  });
}

document.addEventListener('DOMContentLoaded', initializeCharts);
document.addEventListener('turbo:load', initializeCharts);

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

// Collection dependency form validation
function initializeDependencyFormValidation() {
  const form = document.querySelector('[data-dependency-validation]');
  if (!form) return;

  const fileInput = form.querySelector('#collection_dependency_file');
  const repoInput = form.querySelector('#collection_github_repo_url');
  
  if (!fileInput || !repoInput) return;

  form.addEventListener("submit", function (e) {
    // only check if form passes built-in validations
    if (form.checkValidity()) {
      if (!fileInput.value && !repoInput.value) {
        e.preventDefault();
        // make it fail validation-style
        repoInput.setCustomValidity("Provide a GitHub repo URL or upload a dependency file.");
        repoInput.reportValidity();
      } else {
        // clear any previous custom error
        repoInput.setCustomValidity("");
      }
    }
  });
}

document.addEventListener('DOMContentLoaded', initializeDependencyFormValidation);
document.addEventListener('turbo:load', initializeDependencyFormValidation);