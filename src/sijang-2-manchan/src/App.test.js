import { render, screen } from '@testing-library/react';
import App from './App';
import { fireEvent } from '@testing-library/react';
import Modal from './components/Modal';

test('renders the market initial empty state with a load control', () => {
  render(<App />);
  expect(screen.getByText('more')).toBeInTheDocument();
  expect(screen.getAllByRole('img').length).toBeGreaterThan(0);
});

test('market modal renders supplied content and closes through its button', () => {
  const onClose = jest.fn();
  render(<Modal visible onClose={onClose}>Selected market</Modal>);
  expect(screen.getByText('Selected market')).toBeVisible();
  fireEvent.click(screen.getByRole('button', { name: '확인' }));
  expect(onClose).toHaveBeenCalledTimes(1);
});

test('hidden market modal is not exposed as visible content', () => {
  render(<Modal visible={false} onClose={() => {}}>Selected market</Modal>);
  expect(screen.getByText('Selected market')).not.toBeVisible();
});
