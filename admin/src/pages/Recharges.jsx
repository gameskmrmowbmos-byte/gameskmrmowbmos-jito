import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client.js';
import { formatDate } from '../utils/dateFormatters.js';

export default function Recharges() {
  const { data, isLoading } = useQuery({
    queryKey: ['recharges'],
    queryFn: async () => (await api.get('/admin/recharges')).data.data.recharges,
  });
  return (
    <section>
      <div className="page-title"><h1>Recharge History</h1><p>All recharge transactions are retained.</p></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>User</th><th>Plan</th><th>Amount</th><th>Start</th><th>Expiry</th><th>Status</th><th>By</th><th>Note</th></tr></thead>
          <tbody>
            {isLoading && <tr><td colSpan="8">Loading...</td></tr>}
            {(data || []).map((row) => (
              <tr key={row._id}>
                <td>{row.user?.fullName || row.user?.username}</td>
                <td>{row.planName}</td>
                <td>₹ {row.amount}</td>
                <td>{formatDate(row.startDate)}</td>
                <td>{formatDate(row.expiryDate)}</td>
                <td><span className="badge">{row.status}</span></td>
                <td>{row.createdByAdmin?.username}</td>
                <td>{row.note || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
