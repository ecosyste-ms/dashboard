// Project Sync ActionCable functionality
// Global cable connection that persists across Turbo navigation
if (typeof App === 'undefined') {
  window.App = {};
}
if (!App.cable) {
  App.cable = ActionCable.createConsumer();
  console.log('ActionCable consumer created:', App.cable);
}

function initializeProjectSync() {
  const syncStatusElement = document.getElementById('sync-status');
  if (!syncStatusElement) return; // Not on syncing page
  
  const projectId = syncStatusElement.getAttribute('data-project-id');
  if (!projectId) return;
  
  // Clean up any existing subscription for this project
  if (App.projectSyncChannel) {
    App.projectSyncChannel.unsubscribe();
  }
  
  console.log('Creating subscription for project:', projectId);
  
  App.projectSyncChannel = App.cable.subscriptions.create(
    { 
      channel: "ProjectSyncChannel", 
      project_id: projectId
    },
    {
      connected() {
        console.log("Connected to ProjectSyncChannel for project:", projectId);
      },

      disconnected() {
        console.log("Disconnected from ProjectSyncChannel for project:", projectId);
      },

      rejected() {
        console.error("Subscription rejected for project:", projectId);
      },

      received(data) {
        console.log("Received project sync data:", data);
        
        if (data.type === 'test') {
          console.log("Test broadcast received:", data.message, data.timestamp);
          return;
        }
        
        if (data.type === 'status_update' && data.html) {
          // Update the entire sync status area
          syncStatusElement.innerHTML = data.html;
          
          // If sync is complete, redirect to project page
          if (data.ready === true) {
            setTimeout(() => {
              window.location.href = syncStatusElement.getAttribute('data-project-url');
            }, 2000);
          }
        } else if (data.type === 'progress_update') {
          console.log('Handling progress update for project:', data);
          
          // Update progress bar if it exists
          const progressBar = document.querySelector('.progress-bar');
          if (progressBar && data.progress) {
            const percentage = data.progress.percentage;
            console.log('Updating progress bar to:', percentage + '%');
            progressBar.style.width = percentage + '%';
            progressBar.setAttribute('aria-valuenow', data.progress.completed);
            progressBar.textContent = percentage + '%';
          }
        }
      }
    }
  );
}

// Initialize on both initial page load and Turbo navigation
document.addEventListener('DOMContentLoaded', initializeProjectSync);
document.addEventListener('turbo:load', initializeProjectSync);

// Clean up subscriptions when navigating away
document.addEventListener('turbo:before-visit', function() {
  if (App.projectSyncChannel) {
    console.log('Cleaning up project sync subscription before navigation');
    App.projectSyncChannel.unsubscribe();
    App.projectSyncChannel = null;
  }
});