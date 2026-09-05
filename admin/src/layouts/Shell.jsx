import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';

const navItems = [
  ['Dashboard', '/dashboard'],
  ['Users / Customers', '/users'],
  ['Recharge History', '/recharges'],
  ['Plans', '/plans'],
  ['Markets', '/markets'],
  ['Number / Panna Config', '/number-config'],
  ['Audit Logs', '/audit-logs'],
  ['Admin Settings', '/settings'],
];

export default function Shell() {
  const auth = useAuth();
  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <strong>MATKA</strong>
          <span>Admin Panel</span>
        </div>
        <nav>
          {navItems.map(([label, path]) => (
            <NavLink key={path} to={path}>
              {label}
            </NavLink>
          ))}
        </nav>
        <button className="logout" onClick={auth.logout}>Logout</button>
      </aside>
      <main className="content">
        <header className="topbar">
          <div>
            <span className="muted">Signed in as</span>
            <strong>{auth.user?.fullName || auth.user?.username}</strong>
          </div>
        </header>
        <Outlet />
      </main>
    </div>
  );
}
