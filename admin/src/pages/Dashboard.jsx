import { useQuery } from '@tanstack/react-query';
import { api, apiMessage } from '../api/client.js';
import { formatDate } from '../utils/dateFormatters.js';

export default function Dashboard() {
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['dashboard'],
    queryFn: async () => (await api.get('/admin/dashboard')).data.data,
  });
  const summary = data?.summary || {};

  return (
    <section>
      <div className="page-title">
        <h1>Dashboard</h1>
        <p>Subscription and access overview.</p>
      </div>
      {isError && (
        <div className="alert error">
          Unable to load dashboard. {apiMessage(error)}
          <button onClick={() => refetch()}>Retry</button>
        </div>
      )}
      {isLoading ? <p>Loading...</p> : !isError && (
        <>
          <div className="stats-grid">
            {[
              ['Total Customers', summary.totalCustomers],
              ['Active Customers', summary.activeCustomers],
              ['Trial Users', summary.trialUsers],
              ['Active Subscriptions', summary.activeSubscriptions],
              ['Expired Customers', summary.expiredCustomers],
              ['Pending Approval', summary.pendingApproval],
              ['Blocked Customers', summary.blockedCustomers],
              ['Active Recharges', summary.activeRecharges],
              ['Expiring Soon', summary.expiringSoon],
              ['Total Markets', summary.totalMarkets],
            ].map(([label, value]) => (
              <div className="stat-card" key={label}>
                <span>{label}</span>
                <strong>{value ?? 0}</strong>
              </div>
            ))}
          </div>
          <div className="two-col">
            <Panel title="Recent Customers" rows={data?.recentCustomers || []} />
            <Panel title="Expiring Soon" rows={data?.expiringSoonUsers || []} />
          </div>
        </>
      )}
    </section>
  );
}

function Panel({ title, rows }) {
  return (
    <div className="panel">
      <h2>{title}</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Name</th><th>Status</th><th>Expiry</th></tr></thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id || row._id}>
                <td>{row.fullName || row.username}</td>
                <td><span className="badge">{row.accessStatus?.subscriptionStatus}</span></td>
                <td>{formatDate(row.subscriptionExpiryDate)}</td>
              </tr>
            ))}
            {!rows.length && <tr><td colSpan="3">No records</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
