import { utils } from 'ethers';
import { ethers } from 'hardhat';
import TelegramBot from 'node-telegram-bot-api';

const hcAddr = '0x20a3276972380E3c456137E49c32061498311Dd2';
const hclpAddr = '0xdb83d062fa300fb8b00f6ceb79ecc71dfef921a5';
const hclpAbi = [
  'event Mint(address indexed sender, uint amount0, uint amount1)',
  'event Burn(address indexed sender, uint amount0, uint amount1, address indexed to)',
  'event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to)',
  'event Sync(uint112 reserve0, uint112 reserve1)'
];

async function main() {
  const token = process.env.TOKEN as string;
  const bot = new TelegramBot(token, { polling: true });

  const hc = await ethers.getContractAt('HC', hcAddr);
  const hclp = await ethers.getContractAt(hclpAbi, hclpAddr);

  bot.onText(/\/lp/, async (msg, match) => {
    const totalSupply = await hclp.totalSupply();
    const chatId = msg.chat.id;
    const message = `HC LP Total Supply: ${(totalSupply / 1e18).toFixed(4)}`;
    console.log(message);
    bot.sendMessage(chatId, message);
  });

  hclp.on('Mint', (sender, hcAmount, busdAmount, event) => {
    const message = `[Add Liquidity] ${(hcAmount / 1e18).toFixed(4)} HC and ${(busdAmount / 1e18).toFixed(4)} BUSD have been added to the pool`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  const filter = hclp.filters.Transfer('0x0000000000000000000000000000000000000000');
  hclp.on(filter, (from, to, amount, event) => {
    const message = `[Add Liquidity] ${to} got ${(amount / 1e18).toFixed(4)} LP`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  hclp.on('Sync', (hcAmount, busdAmount, event) => {
    const message = `[Pool Info] The pool now has ${(hcAmount / 1e18).toFixed(4)} HC and ${(busdAmount / 1e18).toFixed(4)} BUSD`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });
}

main();
