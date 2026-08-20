// Panvelkar Estate Stanford
// Public-site JavaScript
//
// IMPORTANT:
// No administrator password, user list, or privileged credential is stored here.
// Admin/Super Admin authentication must be handled by Supabase Auth + RLS.

function openAdmin() {
  window.location.href = "portal.html";
}

function closeAdmin() {
  const modal = document.getElementById("adminModal");
  if (modal) {
    modal.classList.remove("show");
  }
}

document.addEventListener("DOMContentLoaded", function () {
  const modal = document.getElementById("adminModal");

  if (modal) {
    modal.addEventListener("click", function (event) {
      if (event.target === modal) {
        closeAdmin();
      }
    });
  }
});