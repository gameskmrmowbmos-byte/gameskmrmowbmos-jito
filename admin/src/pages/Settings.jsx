import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api, apiMessage } from '../api/client.js';

export default function Settings() {
  const qc = useQueryClient();
  const { data } = useQuery({ queryKey: ['admin-settings'], queryFn: async () => (await api.get('/admin/settings')).data.data.settings });
  const [form, setForm] = useState({});
  useEffect(() => { if (data) setForm(data); }, [data]);
  const save = useMutation({
    mutationFn: async () =>
      api.put('/admin/settings', {
        ...form,
        subscriptionWarningDays: Number(form.subscriptionWarningDays ?? 3),
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-settings'] }),
  });
  return (
    <section>
      <div className="page-title"><h1>Admin Settings</h1><p>Registration and subscription warning settings.</p></div>
      <div className="panel form-grid">
        <input aria-label="Application Name" placeholder="Application Name" value={form.applicationName || ''} onChange={(e) => setForm({ ...form, applicationName: e.target.value })} />
        <input aria-label="Expiry Warning Days" type="number" placeholder="Expiry Warning Days" value={form.subscriptionWarningDays || 3} onChange={(e) => setForm({ ...form, subscriptionWarningDays: e.target.value })} />
        <input aria-label="Support Mobile" placeholder="Support Mobile" value={form.supportMobileNumber || ''} onChange={(e) => setForm({ ...form, supportMobileNumber: e.target.value })} />
        <input aria-label="Support WhatsApp" placeholder="Support WhatsApp" value={form.supportWhatsAppNumber || ''} onChange={(e) => setForm({ ...form, supportWhatsAppNumber: e.target.value })} />
        <label className="check"><input type="checkbox" checked={form.allowNewRegistrations !== false} onChange={(e) => setForm({ ...form, allowNewRegistrations: e.target.checked })} /> Allow new registrations</label>
        <label className="check"><input type="checkbox" checked={form.requireManualApproval !== false} onChange={(e) => setForm({ ...form, requireManualApproval: e.target.checked })} /> Require manual approval</label>
        <label className="check"><input type="checkbox" checked={form.singleDeviceLoginEnabled === true} onChange={(e) => setForm({ ...form, singleDeviceLoginEnabled: e.target.checked })} /> Single Device Login</label>
        <p className="muted">Restrict each customer account to one active device at a time.</p>
        <button className="primary" onClick={() => save.mutate()}>Save Settings</button>
      </div>
      {save.error && <div className="alert error">{apiMessage(save.error)}</div>}
      {save.isSuccess && <div className="alert success">Settings saved</div>}
    </section>
  );
}
