import dayjs from 'dayjs'

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'CNY',
    minimumFractionDigits: 2,
  }).format(amount || 0)
}

export function formatDate(date: string | Date): string {
  return dayjs(date).format('MM/DD')
}

export function formatDateTime(date: string | Date): string {
  return dayjs(date).format('YYYY-MM-DD HH:mm')
}

export function formatFullDate(date: string | Date): string {
  return dayjs(date).format('YYYY-MM-DD')
}
