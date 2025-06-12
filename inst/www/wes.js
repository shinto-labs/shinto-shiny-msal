// 5) Everything starts when Shiny’s WebSocket is open
$(document).on("shiny:connected", async function(event) {
  alert("Hi there Wes!")
});
