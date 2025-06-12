// Collection Sync ActionCable functionality
// Global cable connection that persists across Turbo navigation
if (typeof App === 'undefined') {
  window.App = {};
}
if (!App.cable) {
  App.cable = ActionCable.createConsumer();
  console.log('ActionCable consumer created:', App.cable);
}

function initializeCollectionSync() {
  const syncStatusElement = document.getElementById('sync-status');
  if (!syncStatusElement) return; // Not on syncing page
  
  const collectionId = syncStatusElement.getAttribute('data-collection-id');
  if (!collectionId) return;
  
  // Clean up any existing subscription for this collection
  if (App.collectionSyncChannel) {
    App.collectionSyncChannel.unsubscribe();
  }
  
  console.log('Creating subscription for collection:', collectionId);
  
  App.collectionSyncChannel = App.cable.subscriptions.create(
    { 
      channel: "CollectionSyncChannel", 
      collection_id: collectionId
    },
    {
      connected() {
        console.log("Connected to CollectionSyncChannel for collection:", collectionId);
      },

      disconnected() {
        console.log("Disconnected from CollectionSyncChannel for collection:", collectionId);
      },

      rejected() {
        console.error("Subscription rejected for collection:", collectionId);
      },

      received(data) {
        console.log("Received data:", data);
        
        if (data.type === 'test') {
          console.log("Test broadcast received:", data.message, data.timestamp);
          return;
        }
        
        if (data.type === 'status_update' && data.html) {
          // Update the entire sync status area
          syncStatusElement.innerHTML = data.html;
          
          // If sync is complete, redirect to collection page
          if (data.import_status === 'completed' && data.sync_status === 'ready') {
            setTimeout(() => {
              window.location.href = syncStatusElement.getAttribute('data-collection-url');
            }, 2000);
          }
        } else if (data.type === 'progress_update') {
          console.log('Handling progress update:', data.progress);
          
          // Update just the progress numbers
          const progressBadge = document.querySelector('.badge span.spinner-border');
          console.log('Found progress badge:', progressBadge);
          
          if (progressBadge && progressBadge.parentElement) {
            console.log('Updating progress badge text');
            progressBadge.parentElement.innerHTML = `
              <span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>
              ${data.progress.synced} / ${data.progress.total} projects synced
            `;
          } else {
            console.log('Progress badge not found, looking for alternative selectors...');
            // Try alternative selector for the syncing badge
            const syncingBadge = document.querySelector('.badge.bg-warning');
            console.log('Found syncing badge:', syncingBadge);
            if (syncingBadge) {
              syncingBadge.innerHTML = `
                <span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>
                ${data.progress.synced} / ${data.progress.total} projects synced
              `;
            }
          }
          
          // Update progress bar
          const progressBar = document.querySelector('.progress-bar');
          console.log('Found progress bar:', progressBar, 'Total projects:', data.progress.total);
          
          if (progressBar && data.progress.total > 0) {
            const percentage = Math.round((data.progress.synced / data.progress.total) * 100);
            console.log('Updating progress bar to:', percentage + '%');
            progressBar.style.width = percentage + '%';
            progressBar.setAttribute('aria-valuenow', data.progress.synced);
            progressBar.textContent = percentage + '%';
          }
        }
      }
    }
  );
}

// Initialize on both initial page load and Turbo navigation
document.addEventListener('DOMContentLoaded', initializeCollectionSync);
document.addEventListener('turbo:load', initializeCollectionSync);

// Clean up subscriptions when navigating away
document.addEventListener('turbo:before-visit', function() {
  if (App.collectionSyncChannel) {
    console.log('Cleaning up collection sync subscription before navigation');
    App.collectionSyncChannel.unsubscribe();
    App.collectionSyncChannel = null;
  }
});