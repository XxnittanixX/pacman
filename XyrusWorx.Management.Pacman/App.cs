using JetBrains.Annotations;
using XyrusWorx.Management.Pacman.Controllers;

namespace XyrusWorx.Management.Pacman
{
	class App
	{
		[UsedImplicitly]
		private static void Main(string[] args) => new MainController().Run();
	}
}
