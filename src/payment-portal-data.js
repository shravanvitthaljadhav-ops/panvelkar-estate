/*
 * Panvelkar Stanford Payment Portal — V2.0 data adapter
 * Staging scaffold only. Requires the reviewed payment schema and RPCs.
 * No service-role key. No direct writes to derived financial fields.
 *
 * Expected tables:
 *   payment_units
 *   payment_transactions
 *   payment_templates
 *   payment_portal_settings
 *
 * Expected RPC contracts (to be created and tested before enabling writes):
 *   payment_record_transaction({p_unit_id,p_amount,p_payment_date,p_remarks})
 *   payment_update_transaction({p_transaction_id,p_amount,p_payment_date,p_remarks})
 *   payment_delete_transaction({p_transaction_id})
 *   payment_set_outstanding({p_unit_id,p_outstanding})
 *   payment_update_unit_contact({p_unit_id,p_mobile_1,p_mobile_2,p_mobile_3,p_email})
 *   payment_update_flat_status({p_unit_id,p_flat_status})
 *
 * The RPCs must perform authorization, atomic recalculation, and audit logging
 * inside the database transaction. This adapter deliberately does not emulate
 * those guarantees in browser JavaScript.
 */
(function (global) {
  'use strict';

  const TABLES = Object.freeze({
    units: 'payment_units',
    transactions: 'payment_transactions',
    templates: 'payment_templates',
    settings: 'payment_portal_settings'
  });

  function client() {
    if (!global.PaymentPortalAuth) throw new Error('Authentication module is not loaded.');
    return global.PaymentPortalAuth.getClient();
  }

  function assertRows(result, label) {
    if (result.error) throw new Error(label + ': ' + result.error.message);
    return result.data || [];
  }

  function mapTransaction(t) {
    return {
      id: t.id,
      amount: Number(t.amount || 0),
      date: t.payment_date || '',
      remarks: t.remarks || ''
    };
  }

  function mapUnit(row, transactions) {
    const txns = transactions.map(mapTransaction);
    return {
      id: row.id,
      flat: row.unit_key,
      name: row.member_name || '',
      phone: row.mobile_1 || '',
      phones: [row.mobile_2, row.mobile_3].filter(Boolean),
      email: row.email || '',
      otherEmail: '',
      due: Number(row.total_demand || 0),
      received: Number(row.total_received || 0),
      balance: Number(row.outstanding || 0),
      payment: row.payment_status || 'Pending',
      wa: row.whatsapp_status || 'Pending',
      paymentDate: txns.length ? txns.slice().sort((a, b) => String(b.date).localeCompare(String(a.date)))[0].date : '',
      flatStatus: row.flat_status || '',
      unitType: row.unit_type || 'Flat',
      wing: row.wing || '',
      masterUnit: row.unit_key || '',
      waSentAt: row.whatsapp_sent_at || '',
      remarks: row.remarks || '',
      transactions: txns
    };
  }

  function mapTemplate(row) {
    return {
      id: row.id,
      name: row.name,
      category: row.category || '',
      message: row.message || '',
      fileName: row.file_name || '',
      locked: Boolean(row.is_default),
      active: Boolean(row.active)
    };
  }

  async function loadSnapshot() {
    await global.PaymentPortalAuth.requirePaymentAdmin();
    const db = client();

    const unitResult = await db.from(TABLES.units)
      .select('id,unit_key,wing,unit_number,unit_type,member_name,flat_status,mobile_1,mobile_2,mobile_3,email,total_demand,total_received,outstanding,payment_status,whatsapp_status,whatsapp_sent_at,remarks')
      .order('wing', { ascending: true })
      .order('unit_number', { ascending: true });
    const units = assertRows(unitResult, 'Unable to load payment units');

    const unitIds = units.map(u => u.id);
    let transactionRows = [];
    if (unitIds.length) {
      const txResult = await db.from(TABLES.transactions)
        .select('id,unit_id,amount,payment_date,remarks')
        .in('unit_id', unitIds)
        .order('payment_date', { ascending: true });
      transactionRows = assertRows(txResult, 'Unable to load payment transactions');
    }

    const byUnit = new Map();
    transactionRows.forEach(t => {
      if (!byUnit.has(t.unit_id)) byUnit.set(t.unit_id, []);
      byUnit.get(t.unit_id).push(t);
    });

    const templateResult = await db.from(TABLES.templates)
      .select('id,name,category,message,file_name,is_default,active')
      .order('created_at', { ascending: true });
    const templates = assertRows(templateResult, 'Unable to load communication templates');

    const settingsResult = await db.from(TABLES.settings)
      .select('setting_key,setting_value');
    const settings = assertRows(settingsResult, 'Unable to load portal settings');
    const settingsMap = Object.fromEntries(settings.map(s => [s.setting_key, s.setting_value]));

    return {
      data: units.map(u => mapUnit(u, byUnit.get(u.id) || [])),
      templateLibrary: templates.map(mapTemplate),
      activeTemplateId: settingsMap.active_template_id || '',
      loadedAt: new Date().toISOString()
    };
  }

  async function rpc(name, args) {
    await global.PaymentPortalAuth.requirePaymentAdmin();
    const result = await client().rpc(name, args);
    if (result.error) throw new Error(name + ': ' + result.error.message);
    return result.data;
  }

  const api = Object.freeze({
    loadSnapshot,
    recordTransaction: (unitId, amount, date, remarks) =>
      rpc('payment_record_transaction', {
        p_unit_id: unitId, p_amount: Number(amount), p_payment_date: date || null, p_remarks: remarks || ''
      }),
    updateTransaction: (transactionId, amount, date, remarks) =>
      rpc('payment_update_transaction', {
        p_transaction_id: transactionId, p_amount: Number(amount), p_payment_date: date || null, p_remarks: remarks || ''
      }),
    deleteTransaction: transactionId =>
      rpc('payment_delete_transaction', { p_transaction_id: transactionId }),
    setOutstanding: (unitId, outstanding) =>
      rpc('payment_set_outstanding', { p_unit_id: unitId, p_outstanding: Number(outstanding) }),
    updateUnitContact: (unitId, mobile1, mobile2, mobile3, email) =>
      rpc('payment_update_unit_contact', {
        p_unit_id: unitId, p_mobile_1: mobile1 || '', p_mobile_2: mobile2 || '',
        p_mobile_3: mobile3 || '', p_email: email || ''
      }),
    updateFlatStatus: (unitId, flatStatus) =>
      rpc('payment_update_flat_status', { p_unit_id: unitId, p_flat_status: flatStatus || '' })
  });

  global.PaymentPortalData = api;
})(window);
