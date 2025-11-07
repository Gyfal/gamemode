<script>
  import { onMount } from 'svelte';

  let visible = false;
  let dialogData = {
    label: '',
    text: '',
    responses: []
  };

  // Обработка сообщений от клиента
  function handleMessage(event) {
    const { action, data } = event.data;

    switch (action) {
      case 'open':
        dialogData = data;
        visible = true;
        break;

      case 'setDialog':
        dialogData = data;
        break;

      case 'close':
        visible = false;
        break;
    }
  }

  // Обработка клика по ответу
  function handleResponseClick(response) {
    const payload = {
      close: response.close || false,
      data: response.data || null,
      event: response.event || null,
      type: response.type || 'client'
    };

    fetch(`https://${GetParentResourceName()}/click`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (response.close) {
      visible = false;
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

    visible = false;
  }

  // Обработка нажатия ESC
  function handleKeydown(event) {
    if (event.key === 'Escape' && visible) {
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

{#if visible}
  <div class="dialog-container">
    <div class="dialog-header">
      <div class="dialog-label">{dialogData.label}</div>
      <button class="close-btn" on:click={closeDialog}>×</button>
    </div>

    <div class="dialog-text">
      {dialogData.text}
    </div>

    <div class="dialog-responses">
      {#each dialogData.responses as response}
        <button class="response-btn" on:click={() => handleResponseClick(response)}>
          {response.label}
        </button>
      {/each}
    </div>
  </div>
{/if}
