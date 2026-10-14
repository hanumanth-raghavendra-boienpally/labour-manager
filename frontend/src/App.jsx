import { Navigate, Route, Routes, useLocation } from 'react-router';
import { LoginPage } from './auth/LoginPage';
import { useAuth } from './auth/AuthProvider';
import { homePath, Shell } from './layout/Shell';
import { AdminPage } from './pages/AdminPage';
import { AllocationPage } from './pages/AllocationPage';
import { ForecastPage } from './pages/ForecastPage';

/** Each page is reachable only by the role that has it (the API enforces the same rules with 403). */
function Guard({ page, children }) {
  const { status, user } = useAuth();
  const location = useLocation();
  if (status === 'loading') return <div className="loading"><span className="spin" /> Signing you in…</div>;
  if (status !== 'authenticated' || !user) return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  if (!user.pages.includes(page)) return <Navigate to={homePath(user)} replace />;
  return <Shell>{children}</Shell>;
}

function Home() {
  const { status, user } = useAuth();
  if (status === 'loading') return <div className="loading"><span className="spin" /> Signing you in…</div>;
  return <Navigate to={user ? homePath(user) : '/login'} replace />;
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/forecast" element={<Guard page="forecast"><ForecastPage /></Guard>} />
      <Route path="/allocation" element={<Guard page="allocation"><AllocationPage /></Guard>} />
      <Route path="/admin" element={<Guard page="admin"><AdminPage /></Guard>} />
      <Route path="*" element={<Home />} />
    </Routes>
  );
}
