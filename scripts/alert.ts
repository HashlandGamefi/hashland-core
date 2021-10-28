import { utils } from 'ethers';
import { ethers } from 'hardhat';
import TelegramBot from 'node-telegram-bot-api';

async function main() {
  const token = process.env.TOKEN as string;
  const bot = new TelegramBot(token, { polling: true });
  bot.onText(/\/echo (.+)/, (msg, match) => {
    const chatId = msg.chat.id;
    const message = (match as any)[1];
    console.log(message);
    bot.sendMessage(chatId, message);
  });

  const hc = await ethers.getContractAt('HC', '0x20a3276972380E3c456137E49c32061498311Dd2');
  const filter = hc.filters.Transfer(null, '0xdb83d062fa300fb8b00f6ceb79ecc71dfef921a5')
  hc.on(filter, (from, to, amount, event) => {
    const message = `${from} sell ${utils.formatEther(amount)} HC`;
    console.log(message);
    bot.sendMessage('@VivilyChan', message);
  });
}

main();
