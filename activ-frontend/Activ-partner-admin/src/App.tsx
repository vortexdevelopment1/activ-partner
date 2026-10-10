import { Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/layout/Layout';
import { Login } from './pages/auth/Login';
import { Dashboard } from './pages/dashboard/Dashboard';
import { CategoriesList } from './pages/categories/CategoriesList';
import { QuestionsList } from './pages/questions/QuestionsList';
import { VenuesList } from './pages/venues/VenuesList';
import { VenueDetail } from './pages/venues/VenueDetail';
import { UsersList } from './pages/users/UsersList';
import { PartnersList } from './pages/partners/PartnersList';
import { CommissionsList } from './pages/commissions/CommissionsList';
import { LegalPage } from './pages/legal/LegalPage';
import { BankAccountsList } from './pages/bank-accounts/BankAccountsList';
import { BankAccountDetail } from './pages/bank-accounts/BankAccountDetail';
import { CallbackList } from './pages/support/CallbackList';
import { CallbackDetail } from './pages/support/CallbackDetail';
import { FAQsList } from './pages/faqs/FAQsList';
import { GstVerificationList } from './pages/gst-verification/GstVerificationList';
import { GstVerificationDetail } from './pages/gst-verification/GstVerificationDetail';
import { VenueRequestsList } from './pages/venue-requests/VenueRequestsList';
import { VenueRequestDetail } from './pages/venue-requests/VenueRequestDetail';
import { ActivityApprovalList } from './pages/activities/ActivityApprovalList';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<Layout />}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="categories" element={<CategoriesList />} />
        <Route path="questions" element={<QuestionsList />} />
        <Route path="venues" element={<VenuesList />} />
        <Route path="venues/:id" element={<VenueDetail />} />
        <Route path="users" element={<UsersList />} />
        <Route path="partners" element={<PartnersList />} />
        <Route path="commissions" element={<CommissionsList />} />
        <Route path="legal" element={<LegalPage />} />
        <Route path="bank-accounts" element={<BankAccountsList />} />
        <Route path="bank-accounts/:id" element={<BankAccountDetail />} />
        <Route path="faqs" element={<FAQsList />} />
        <Route path="gst-verification" element={<GstVerificationList />} />
        <Route path="gst-verification/:id" element={<GstVerificationDetail />} />
        <Route path="venue-requests" element={<VenueRequestsList />} />
        <Route path="venue-requests/:id" element={<VenueRequestDetail />} />
        <Route path="activity-approvals" element={<ActivityApprovalList />} />
        <Route path="support/callback" element={<CallbackList />} />
        <Route path="support/callback/:id" element={<CallbackDetail />} />
      </Route>
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}
