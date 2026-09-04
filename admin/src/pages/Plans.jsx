import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api, apiMessage } from '../api/client.js';

const empty = { name: '', code: '', validityDays: 30, price: 0, description: '', isActive: true };

export default function Plans() {
  const qc = useQueryClient();
  const [form, setForm] = useState(empty);
  const { data } = useQuery({
    queryKey: ['plans'],
    queryFn: async () => (await api.get('/admin/plans')).data.data.plans,
  });
  const save = useMutation({
    mutationFn: async () => api.post('/admin/plans', form),
    onSuccess: () => { setForm(empty); qc.invalidateQueries({ queryKey: ['plans'] }); },
  });
  const status = useMutation({
    mutationFn: async ({ id, active }) => api.post(`/admin/plans/${id}/${active ? 'deactivate' : 'activate'}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['plans'] }),
  });
  return (
    <section>
      <div className="page-title"><h1>Recharge Plans</h1><p>Admin-only plan configuration.</p></div>
      <div className="panel form-grid">
        <input placeholder="Plan name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        <input placeholder="Code" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} />
        <input type="number" placeholder="Days" value={form.validityDays} onChange={(e) => setForm({ ...form, validityDays: e.target.value })} />
        <input type="number" placeholder="Price" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
        <input placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        <button className="primary" onClick={() => save.mutate()}>Create Plan</button>
      </div>
      {save.error && <div className="alert error">{apiMessage(save.error)}</div>}
      <Cards rows={data || []} render={(plan) => (
        <>
          <strong>{plan.name}</strong><span>{plan.code}</span><span>{plan.validityDays} days</span><span>₹ {plan.price}</span>
          <button onClick={() => status.mutate({ id: plan._id, active: plan.isActive })}>{plan.isActive ? 'Deactivate' : 'Activate'}</button>
        </>
      )} />
    </section>
  );
}

function Cards({ rows, render }) {
  return <div className="cards">{rows.map((row) => <div className="card" key={row._id}>{render(row)}</div>)}</div>;
}
