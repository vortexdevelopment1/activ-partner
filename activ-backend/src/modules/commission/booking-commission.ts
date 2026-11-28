export function computeBookingCommission(totalAmount: number, commissionPercent: number) {
  const round2 = (amount: number) => Math.round(amount * 100) / 100;
  const activCommission = round2((totalAmount * commissionPercent) / 100);
  const gstOnCommission = round2(activCommission * 0.18);
  const netReceived = round2(totalAmount - activCommission - gstOnCommission);
  return { commissionPercent, activCommission, gstOnCommission, netReceived };
}
