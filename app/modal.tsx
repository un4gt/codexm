import { Link } from 'expo-router';
import { StyleSheet } from 'react-native';
import { Button, Text } from 'react-native-paper';

import { ThemedView } from '@/components/themed-view';

export default function ModalScreen() {
  return (
    <ThemedView style={styles.container}>
      <Text variant="headlineMedium">这是一个弹窗</Text>
      <Link href="/" dismissTo asChild>
        <Button mode="contained" style={styles.link}>
          返回首页
        </Button>
      </Link>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  link: {
    marginTop: 15,
  },
});
