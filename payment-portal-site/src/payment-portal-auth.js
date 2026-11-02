/*
 * Panvelkar Stanford Payment Portal — V2.0 auth gate
 * Staging-only integration scaffold. No credentials or resident data belong here.
 *
 * Load Supabase JS v2 (pinned version) before this file and configure
 * window.PAYMENT_PORTAL_CONFIG with the project URL and publishable key.
 * Never place a service-role/secret key in browser code.
 */
(function (global) {
  'use strict';

  const CONFIG = global.PAYMENT_PORTAL_CONFIG || {};
  let client = null;
  let authSubscription = null;

  function requireConfig() {
    if (!CONFIG.supabaseUrl || !CONFIG.publishableKey) {
      throw new Error('Payment portal configuration is incomplete.');
    }
    if (!global.supabase || typeof global.supabase.createClient !== 'function') {
      throw new Error('Supabase JS v2 must be loaded before the payment portal auth module.');
    }
  }

  function getClient() {
    if (client) return client;
    requireConfig();
    client = global.supabase.createClient(CONFIG.supabaseUrl, CONFIG.publishableKey, {
      auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
        storageKey: 'panvelkar_payment_portal_auth'
      }
    });
    return client;
  }

  function isPaymentAdmin(session) {
    const token = session && session.access_token;
    if (!token) return false;
    try {
      const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const claims = JSON.parse(global.atob(payload));
      return claims.payment_admin === true;
    } catch (_) {
      return false;
    }
  }

  async function requirePaymentAdmin() {
    const supabase = getClient();
    const result = await supabase.auth.getSession();
    if (result.error) throw result.error;
    const session = result.data && result.data.session;
    if (!session || !isPaymentAdmin(session)) {
      if (session) await supabase.auth.signOut();
      throw new Error('Access denied. This account is not authorised for the payment portal.');
    }
    return session;
  }

  async function signIn(email, password) {
    const supabase = getClient();
    const result = await supabase.auth.signInWithPassword({
      email: String(email || '').trim(),
      password: String(password || '')
    });
    if (result.error) throw result.error;
    if (!isPaymentAdmin(result.data.session)) {
      await supabase.auth.signOut();
      throw new Error('Access denied. Please contact the society portal owner.');
    }
    return { user: result.data.user, session: result.data.session };
  }

  async function signOut() {
    const supabase = getClient();
    const result = await supabase.auth.signOut();
    if (result.error) throw result.error;
    return true;
  }

  function onAuthStateChange(callback) {
    const supabase = getClient();
    if (authSubscription) authSubscription.unsubscribe();
    const result = supabase.auth.onAuthStateChange((event, session) => {
      const allowed = isPaymentAdmin(session);
      if (typeof callback === 'function') callback({ event, session: allowed ? session : null, allowed });
      if (session && !allowed) {
        // The database RLS remains the security boundary; this is a UI/session gate.
        Promise.resolve().then(() => supabase.auth.signOut());
      }
    });
    authSubscription = result.data.subscription;
    return () => {
      if (authSubscription) authSubscription.unsubscribe();
      authSubscription = null;
    };
  }

  global.PaymentPortalAuth = Object.freeze({
    getClient,
    signIn,
    signOut,
    requirePaymentAdmin,
    isPaymentAdmin,
    onAuthStateChange
  });
})(window);
