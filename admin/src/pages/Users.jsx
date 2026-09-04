import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api, apiMessage } from '../api/client.js';

export default function Users() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [rechargeUser, setRechargeUser] = useState(null);
  const [confirmAction, setConfirmAction] = useState(null);
  const { data, isLoading, isError, error, refetch, isFetching } = useQuery({
    queryKey: ['admin-users', search],
    queryFn: async () => (await api.get('/admin/users', { params: { search } })).data.data.users,
  });
  const action = useMutation({
    mutationFn: async ({ id, type }) => api.post(`/admin/users/${id}/${type}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  function runAction(user, type) {
    if (type === 'approve' || type === 'reset-device') {
      setConfirmAction({ user, type });
      return;
    }
    action.mutate({ id: user.id, type });
  }

  return (
    <section>
      <div className="page-title"><h1>Users / Customers</h1><p>Approve, block, and recharge Flutter app users.</p></div>
      <div className="toolbar">
        <input placeholder="Search name/mobile/username" value={search} onChange={(e) => setSearch(e.target.value)} />
        <button onClick={() => refetch()} disabled={isFetching}>{isFetching ? 'Refreshing...' : 'Refresh'}</button>
      </div>
      {isError && <div className="alert error">Unable to fetch users. {apiMessage(error)} <button onClick={() => refetch()}>Retry</button></div>}
      {action.error && <div className="alert error">{apiMessage(action.error)}</div>}
      <div className="table-wrap">
        <table>
          <thead><tr><th>Name</th><th>Mobile</th><th>Email</th><th>Registered On</th><th>Approval</th><th>Entry Access</th><th>Subscription</th><th>Device Login</th><th>Actions</th></tr></thead>
          <tbody>
            {isLoading && <tr><td colSpan="9">Loading...</td></tr>}
            {!isLoading && !isError && !(data || []).length && <tr><td colSpan="9">No registered users found.</td></tr>}
            {!isError && (data || []).map((user) => (
              <tr key={user.id}>
                <td><strong>{user.fullName}</strong><br /><span className="muted">{user.email}</span></td>
                <td>{user.phoneNumber || '-'}</td>
                <td><Badge value={user.emailVerified ? 'VERIFIED' : 'NOT VERIFIED'} /></td>
                <td>{user.createdAt ? new Date(user.createdAt).toLocaleDateString() : '-'}</td>
                <td><Badge value={user.approvalStatus} /></td>
                <td><Badge value={user.entryAccessBlocked ? 'BLOCKED' : 'ALLOWED'} /></td>
                <td><Badge value={`${user.accessStatus?.subscriptionType || user.subscriptionType} ${user.accessStatus?.subscriptionStatus || ''}`} /></td>
                <td>{user.activeDeviceIdMasked ? <><Badge value="Active Device" /><br /><span className="muted">{user.activeDeviceIdMasked}</span></> : <Badge value="Not Bound" />}</td>
                <td className="actions">
                  {user.approvalStatus !== 'APPROVED' && <button onClick={() => runAction(user, 'approve')}>Approve</button>}
                  {user.entryAccessBlocked ? (
                    <button onClick={() => runAction(user, 'unblock')}>Unblock</button>
                  ) : (
                    user.approvalStatus === 'APPROVED' && <button onClick={() => runAction(user, 'block')}>Block</button>
                  )}
                  <button onClick={() => runAction(user, 'reset-device')}>Reset Device Login</button>
                  <button className="primary" onClick={() => setRechargeUser(user)}>Recharge</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {rechargeUser && <RechargeModal user={rechargeUser} onClose={() => setRechargeUser(null)} />}
      {confirmAction && (
        <div className="modal-backdrop">
          <div className="modal">
            <h2>{confirmAction.type === 'approve' ? 'Approve User?' : 'Reset Device Login?'}</h2>
            <p>
              {confirmAction.type === 'approve'
                ? `Approve "${confirmAction.user.fullName}" and start their trial if it has not started yet?`
                : 'This will sign this account out from its currently registered device and allow login from another device.'}
            </p>
            <div className="modal-actions">
              <button onClick={() => setConfirmAction(null)}>Cancel</button>
              <button className="primary" onClick={() => {
                action.mutate({ id: confirmAction.user.id, type: confirmAction.type });
                setConfirmAction(null);
              }}>{confirmAction.type === 'approve' ? 'Approve' : 'Reset Device'}</button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

function RechargeModal({ user, onClose }) {
  const qc = useQueryClient();
  const [form, setForm] = useState({ validityDays: 30, amount: 0, startMode: 'FROM_CURRENT_EXPIRY', paymentMode: 'Cash', note: '' });
  const { data: plans } = useQuery({
    queryKey: ['plans-active'],
    queryFn: async () => (await api.get('/admin/plans', { params: { status: 'active' } })).data.data.plans,
  });
  const mutation = useMutation({
    mutationFn: async () => api.post(`/admin/users/${user.id}/recharge`, form),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-users'] });
      qc.invalidateQueries({ queryKey: ['recharges'] });
      onClose();
    },
  });

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <h2>Recharge {user.fullName}</h2>
        <p>Current expiry: {user.subscriptionExpiryDate ? new Date(user.subscriptionExpiryDate).toLocaleDateString() : 'Not active'}</p>
        <label>Plan<select onChange={(e) => {
          const plan = (plans || []).find((item) => item._id === e.target.value);
          setForm({ ...form, planId: plan?._id, validityDays: plan?.validityDays || form.validityDays, amount: plan?.price ?? form.amount });
        }}><option value="">Custom</option>{(plans || []).map((plan) => <option key={plan._id} value={plan._id}>{plan.name}</option>)}</select></label>
        <label>Validity Days<input type="number" value={form.validityDays} onChange={(e) => setForm({ ...form, validityDays: e.target.value })} /></label>
        <label>Amount<input type="number" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
        <label>Start<select value={form.startMode} onChange={(e) => setForm({ ...form, startMode: e.target.value })}><option value="FROM_CURRENT_EXPIRY">From Current Expiry</option><option value="FROM_TODAY">From Today</option></select></label>
        <label>Payment<select value={form.paymentMode} onChange={(e) => setForm({ ...form, paymentMode: e.target.value })}><option>Cash</option><option>UPI</option><option>Bank Transfer</option><option>Other</option></select></label>
        <label>Note<textarea value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} /></label>
        {mutation.error && <div className="alert error">{apiMessage(mutation.error)}</div>}
        <div className="modal-actions"><button onClick={onClose}>Cancel</button><button className="primary" onClick={() => mutation.mutate()}>Activate Recharge</button></div>
      </div>
    </div>
  );
}

function Badge({ value }) {
  return <span className={`badge ${String(value || '').toLowerCase()}`}>{value || '-'}</span>;
}
