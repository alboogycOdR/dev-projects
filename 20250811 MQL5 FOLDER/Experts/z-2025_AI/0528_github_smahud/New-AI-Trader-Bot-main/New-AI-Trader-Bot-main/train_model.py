import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
import torch.onnx

# Definição do modelo LSTM
class LSTMModel(nn.Module):
    def __init__(self, input_size, hidden_size, output_size, num_layers=1):
        super(LSTMModel, self).__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=True)
        self.fc = nn.Linear(hidden_size, output_size)

    def forward(self, x):
        out, _ = self.lstm(x)
        out = self.fc(out[:, -1, :])  # Apenas a última saída
        return out

# Configurações do modelo
INPUT_SIZE = 5  # OHLCV
HIDDEN_SIZE = 64
OUTPUT_SIZE = 3  # [Nada, Compra, Venda]
NUM_LAYERS = 1
EPOCHS = 50
BATCH_SIZE = 32
LEARNING_RATE = 0.001

# Criar o modelo, função de perda e otimizador
model = LSTMModel(INPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE, NUM_LAYERS)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

# Dados fictícios (substitua pelos dados reais de OHLCV)
# Cada entrada tem 100 candles com 5 valores (OHLCV)
x_train = np.random.rand(1000, 100, 5).astype(np.float32)
y_train = np.random.randint(0, 3, size=(1000,)).astype(np.int64)

# Converta para tensores PyTorch
x_train = torch.tensor(x_train)
y_train = torch.tensor(y_train)

# Treinamento do modelo
for epoch in range(EPOCHS):
    model.train()
    for i in range(0, len(x_train), BATCH_SIZE):
        x_batch = x_train[i:i+BATCH_SIZE]
        y_batch = y_train[i:i+BATCH_SIZE]

        # Forward pass
        outputs = model(x_batch)
        loss = criterion(outputs, y_batch)

        # Backward pass e otimização
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

    print(f"Epoch [{epoch+1}/{EPOCHS}], Loss: {loss.item():.4f}")

# Salvar o modelo como ONNX
dummy_input = torch.randn(1, 100, 5)  # Exemplo de entrada
onnx_path = "model.onnx"
torch.onnx.export(model, dummy_input, onnx_path, export_params=True, opset_version=11,
                  input_names=["input"], output_names=["output"])
print(f"Modelo ONNX salvo em: {onnx_path}")
