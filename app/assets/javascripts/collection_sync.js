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
        
        // For any update that includes HTML, replace the entire content
        if (data.html) {
          console.log("Updating entire sync status area with new HTML");
          
          // Replace the content while preserving the container
          syncStatusElement.innerHTML = data.html;
          
          // If sync is complete, redirect to collection page
          if (data.sync_status === 'ready') {
            console.log('Sync complete, redirecting in 2 seconds...');
            setTimeout(() => {
              window.location.href = syncStatusElement.getAttribute('data-collection-url');
            }, 2000);
          }
        } else {
          console.log("No HTML in update, skipping DOM update");
          // Still check for redirect even without HTML update
          if (data.sync_status === 'ready' && data.progress && data.progress.synced === data.progress.total) {
            console.log('Sync complete (no HTML), redirecting in 2 seconds...');
            setTimeout(() => {
              window.location.href = syncStatusElement.getAttribute('data-collection-url');
            }, 2000);
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