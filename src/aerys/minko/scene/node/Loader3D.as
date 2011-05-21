package aerys.minko.scene.node
{
	import aerys.minko.scene.node.group.Group;
	import aerys.minko.scene.node.texture.BitmapTexture;
	import aerys.minko.scene.node.texture.ITexture;
	import aerys.minko.scene.node.texture.MovieClipTexture;
	import aerys.minko.scene.visitor.ISceneVisitor;
	import aerys.minko.type.parser.IParser3D;
	
	import flash.display.Bitmap;
	import flash.display.IBitmapDrawable;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	public class Loader3D extends EventDispatcher implements IScene
	{
		private static const FORMATS	: RegExp	= /^.*\.(swf|jpg|png)$/s
		private static const PARSERS	: Object	= new Object();
		
		private var _loaderToURI		: Dictionary	= new Dictionary(true);
		private var _content			: Group			= new Group();
		
		public function get name()	 	: String	{ return _content.name; }
		public function get content() 	: Group		{ return _content; }
		
		public static function registerParser(extension : String,
											  parser 	: IParser3D) : void
		{
			PARSERS[extension] = parser;
		}
		
		public function Loader3D()
		{
			
		}
		
		public function load(request : URLRequest) : Group
		{
			if (request.url.match(FORMATS))
			{
				var loader : Loader = new Loader();
				
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE,
														  loaderCompleteHandler);
				loader.load(request);
			}
			else
			{
				var urlLoader 	: URLLoader	= new URLLoader();
				var uri			: String	= request.url;
				var extension	: String	= uri.substr(uri.lastIndexOf(".") + 1);
				var parser		: IParser3D	= PARSERS[extension.toLocaleLowerCase()];
				
				if (!parser)
					throw new Error("No data parser registered for extension '" + extension + "'");

				_loaderToURI[urlLoader] = request.url;
				
				urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
				urlLoader.addEventListener(Event.COMPLETE, urlLoaderCompleteHandler);
				urlLoader.load(request);
			}
			
			return _content;
		}
		
		public static function loadBytes(bytes : ByteArray) : Group
		{
			for (var extension : String in PARSERS)
			{
				var parser : IParser3D = PARSERS[extension];
				
				bytes.position = 0;
				
				if (parser.parse(bytes))
				{
					var data	: Vector.<IScene>	= parser.data;
					var length	: int				= data ? data.length : 0;
					var content : Group				= new Group();

					for (var i : int = 0; i < length; ++i)
						content.addChild(data[i]);
					
					return content;
				}
			}
			
			throw new Error("Unable to find a proper data parser.");
			
			return null;
		}
		
		public static function loadAsset(asset : Class) : Group
		{
			var assetObject : Object 	= new asset();
			
			if (assetObject is MovieClip)
			{
				var mc 		: MovieClip	= assetObject as MovieClip;
				var loader 	: Loader 	= null;
				
				if (mc.numChildren == 1 && (loader = mc.getChildAt(0) as Loader))
				{
					var texture : MovieClipTexture = new MovieClipTexture();
					
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE,
															  function(e : Event) : void
					{
						texture.source = loader.content as MovieClip;
					});

					return new Group(texture);
				}
				else
				{
					return new Group(new MovieClipTexture(mc));
				}
			}
			else if (assetObject is IBitmapDrawable)
			{
				return new Group(BitmapTexture.fromDisplayObject(assetObject as Bitmap));
			}
			else if (assetObject is ByteArray)
			{
				return loadBytes(assetObject as ByteArray);
			}
			
			return null;
		}
		
		private function urlLoaderCompleteHandler(event : Event) : void
		{
			var loader 		: URLLoader			= event.target as URLLoader;
			var uri			: String			= _loaderToURI[loader];
			var extension	: String			= uri.substr(uri.lastIndexOf(".") + 1);
			var parser		: IParser3D			= PARSERS[extension.toLocaleLowerCase()];
			var data		: Vector.<IScene>	= parser.parse(loader.data as ByteArray)
												  ? parser.data
												  : null;
			var length		: int				= data ? data.length : 0;
			
			_content.removeAllChildren();
			for (var i : int = 0; i < length; ++i)
				_content.addChild(data[i]);

			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private static function embedCompleteHandler(event : Event) : void
		{
			
		}
		
		private function loaderCompleteHandler(event : Event) : void
		{
			var info 	: LoaderInfo 	= event.target as LoaderInfo;
			var texture	: ITexture 		= null;
						
			if (info.content is MovieClip)
				texture = new MovieClipTexture(info.content as MovieClip);
			else if (info.content is Bitmap)
				texture = new BitmapTexture((info.content as Bitmap).bitmapData);
			
			_content.removeAllChildren();
			_content.addChild(texture);
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function visited(query : ISceneVisitor) : void
		{
			query.visit(_content);
		}
	}
}