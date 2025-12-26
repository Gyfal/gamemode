<script>
  import { onMount } from 'svelte';

  let dialogVisible = false;
  let promptVisible = false;
  let promptText = '';
  let npcName = '';
  let dialogs = [];

  // Обработка сообщений от клиента
  function handleMessage(event) {
    const { action, npcName: name, dialogs: dialogList, text } = event.data;

    switch (action) {
      case 'open':
        npcName = name || 'NPC';
        dialogs = (dialogList || []).map(d => ({...d, expanded: false}));
        dialogVisible = true;
        break;

      case 'close':
        dialogVisible = false;
        dialogs = [];
        break;

      case 'showPrompt':
        promptText = text || '';
        promptVisible = true;
        break;

      case 'hidePrompt':
        promptVisible = false;
        break;
    }
  }

  // Переключение раскрытия диалога
  function toggleDialog(index) {
    dialogs = dialogs.map((d, i) => ({
      ...d,
      expanded: i === index ? !d.expanded : d.expanded
    }));
  }

  // Обработка действия
  function handleAction(action) {
    fetch(`https://${GetParentResourceName()}/action`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        event: action.event || null,
        type: action.type || 'client',
        closeAfter: action.closeAfter || false
      })
    });

    if (action.closeAfter) {
      dialogVisible = false;
    }
  }

  // Закрытие диалога
  function closeDialog() {
    fetch(`https://${GetParentResourceName()}/close`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({})
    });

    dialogVisible = false;
  }

  // Обработка нажатия ESC
  function handleKeydown(event) {
    if (event.key === 'Escape' && dialogVisible) {
      closeDialog();
    }
  }

  // Получение имени ресурса
  function GetParentResourceName() {
    if (window.location.hostname === 'localhost') {
      return 'hf_busdialog';
    }

    const url = new URL(window.location.href);
    const pathParts = url.pathname.split('/');
    return pathParts[pathParts.length - 2];
  }

  onMount(() => {
    window.addEventListener('message', handleMessage);
    window.addEventListener('keydown', handleKeydown);

    return () => {
      window.removeEventListener('message', handleMessage);
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

<!-- Подсказка внизу по центру -->
{#if promptVisible}
  <div class="interaction-prompt">
    <div class="prompt-text">{promptText}</div>
  </div>
{/if}

<!-- Диалоговое окно -->
{#if dialogVisible}
  <div class="dialog-overlay">
    <!-- Правая панель с диалогами -->
    <div class="dialog-panel">
      <div class="dialog-header">
        <div class="npc-name">{npcName}</div>
        <button class="close-btn" on:click={closeDialog}>✕</button>
      </div>

      <div class="dialog-list">
        {#each dialogs as dialog, index}
          <div class="dialog-item" class:expanded={dialog.expanded}>
            <button class="dialog-title" on:click={() => toggleDialog(index)}>
              <span>{dialog.title}</span>
              <span class="arrow">{dialog.expanded ? '▼' : '▶'}</span>
            </button>

            {#if dialog.expanded}
              <div class="dialog-content">
                <p class="dialog-text">{dialog.text}</p>

                {#if dialog.actions && dialog.actions.length > 0}
                  <div class="dialog-actions">
                    {#each dialog.actions as action}
                      <button class="action-btn" on:click={() => handleAction(action)}>
                        {action.label}
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
            {/if}
          </div>
        {/each}
      </div>
    </div>
  </div>
{/if}

<style>
  /* Подсказка взаимодействия */
  .interaction-prompt {
    position: fixed;
    bottom: 80px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 1000;
  }

  .prompt-text {
    background: rgba(0, 0, 0, 0.8);
    color: white;
    padding: 12px 24px;
    border-radius: 8px;
    font-size: 16px;
    font-weight: 500;
    border: 2px solid rgba(255, 255, 255, 0.3);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
    animation: pulse 2s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
  }

  /* Оверлей диалога */
  .dialog-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    display: flex;
    justify-content: flex-end;
    align-items: center;
    z-index: 2000;
    pointer-events: none;
  }

  /* Правая панель */
  .dialog-panel {
    width: 450px;
    max-height: 90vh;
    background: linear-gradient(135deg, rgba(20, 20, 30, 0.95) 0%, rgba(10, 10, 20, 0.95) 100%);
    border-left: 2px solid rgba(255, 255, 255, 0.1);
    box-shadow: -10px 0 40px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    pointer-events: all;
    animation: slideInRight 0.3s ease-out;
  }

  @keyframes slideInRight {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }

  /* Заголовок */
  .dialog-header {
    padding: 25px;
    border-bottom: 2px solid rgba(255, 255, 255, 0.1);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .npc-name {
    font-size: 24px;
    font-weight: 700;
    color: #fff;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
  }

  .close-btn {
    background: rgba(255, 50, 50, 0.2);
    border: 2px solid rgba(255, 50, 50, 0.5);
    color: #ff5555;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    cursor: pointer;
    font-size: 24px;
    font-weight: bold;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
  }

  .close-btn:hover {
    background: rgba(255, 50, 50, 0.4);
    transform: rotate(90deg);
  }

  /* Список диалогов */
  .dialog-list {
    flex: 1;
    overflow-y: auto;
    padding: 15px;
  }

  .dialog-list::-webkit-scrollbar {
    width: 8px;
  }

  .dialog-list::-webkit-scrollbar-track {
    background: rgba(0, 0, 0, 0.2);
  }

  .dialog-list::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.3);
    border-radius: 4px;
  }

  .dialog-list::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.5);
  }

  /* Элемент диалога */
  .dialog-item {
    margin-bottom: 12px;
    border-radius: 12px;
    overflow: hidden;
    background: rgba(30, 30, 40, 0.6);
    border: 2px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s ease;
  }

  .dialog-item:hover {
    border-color: rgba(255, 255, 255, 0.15);
    transform: translateX(5px);
  }

  .dialog-item.expanded {
    border-color: rgba(70, 130, 255, 0.5);
    background: rgba(40, 40, 50, 0.8);
  }

  /* Заголовок диалога */
  .dialog-title {
    width: 100%;
    padding: 15px 20px;
    background: transparent;
    border: none;
    color: #fff;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    transition: all 0.2s ease;
    text-align: left;
  }

  .dialog-title:hover {
    background: rgba(255, 255, 255, 0.05);
  }

  .arrow {
    font-size: 14px;
    transition: transform 0.3s ease;
    color: rgba(255, 255, 255, 0.6);
  }

  /* Содержимое диалога */
  .dialog-content {
    padding: 0 20px 20px 20px;
    animation: expandContent 0.3s ease-out;
  }

  @keyframes expandContent {
    from {
      opacity: 0;
      max-height: 0;
    }
    to {
      opacity: 1;
      max-height: 500px;
    }
  }

  .dialog-text {
    color: rgba(255, 255, 255, 0.85);
    font-size: 14px;
    line-height: 1.6;
    margin-bottom: 15px;
  }

  /* Кнопки действий */
  .dialog-actions {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 15px;
  }

  .action-btn {
    background: linear-gradient(135deg, rgba(70, 130, 255, 0.3) 0%, rgba(50, 100, 220, 0.3) 100%);
    border: 2px solid rgba(70, 130, 255, 0.5);
    color: #fff;
    padding: 12px 20px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 15px;
    font-weight: 600;
    transition: all 0.3s ease;
    position: relative;
    overflow: hidden;
  }

  .action-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.5s ease;
  }

  .action-btn:hover::before {
    left: 100%;
  }

  .action-btn:hover {
    background: linear-gradient(135deg, rgba(70, 130, 255, 0.5) 0%, rgba(50, 100, 220, 0.5) 100%);
    border-color: rgba(70, 130, 255, 0.8);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(70, 130, 255, 0.4);
  }

  .action-btn:active {
    transform: translateY(0);
  }

  /* Адаптивность */
  @media (max-width: 768px) {
    .dialog-panel {
      width: 100%;
      max-width: 100%;
    }

    .interaction-prompt {
      bottom: 60px;
    }

    .prompt-text {
      font-size: 14px;
      padding: 10px 20px;
    }
  }
</style>
